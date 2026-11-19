// Command server 是后端入口。
//
//	go run ./cmd/server                 启动 HTTP 服务（GET /healthz；配置齐全时挂载 /api/v1）
//	go run ./cmd/server -migrate up     执行数据库迁移后退出
//	go run ./cmd/server -migrate down   回滚一步后退出（开发用）
//
// 配置全部来自环境变量（见 backend/.env.example）；本程序不读取 .env 文件，
// 本地开发请用 `set -a; source .env; set +a` 或进程管理工具注入。
package main

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/imamura-akira/New_FinX/backend/internal/auth"
	"github.com/imamura-akira/New_FinX/backend/internal/config"
	"github.com/imamura-akira/New_FinX/backend/internal/dwclient"
	"github.com/imamura-akira/New_FinX/backend/internal/store"
)

// version 可在构建时用 -ldflags "-X main.version=..." 注入。
var version = "dev"

func main() {
	migrateCmd := flag.String("migrate", "", "执行数据库迁移：up 或 down，完成后退出")
	flag.Parse()

	logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: slog.LevelInfo}))
	slog.SetDefault(logger)

	if err := run(*migrateCmd, logger); err != nil {
		logger.Error("server exited", slog.String("error", err.Error()))
		os.Exit(1)
	}
}

func run(migrateCmd string, logger *slog.Logger) error {
	cfg, err := config.Load()
	if err != nil {
		return err
	}
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	// 数据库（可选：未配置时 health 报告 not_configured，便于先跑通骨架）
	var st *store.Store
	if cfg.DatabaseURL != "" {
		st, err = store.Open(ctx, cfg.DatabaseURL)
		if err != nil {
			return err
		}
		defer st.Close()
	}
	if migrateCmd != "" {
		if st == nil {
			return store.ErrNoDatabaseURL
		}
		switch migrateCmd {
		case "up":
			err = st.MigrateUp()
		case "down":
			err = st.MigrateDown()
		default:
			return fmt.Errorf("未知的 -migrate 参数 %q（可选 up / down）", migrateCmd)
		}
		if err == nil {
			logger.Info("migration done", slog.String("direction", migrateCmd))
		}
		return err
	}

	// DW 客户端：只创建，不在启动时申请 token（节省 token 预算）
	var dw *dwclient.Client
	if cfg.DWConfigured() {
		dw, err = dwclient.New(dwclient.Config{
			BaseURL: cfg.DW.BaseURL, AppKey: cfg.DW.AppKey, ClientID: cfg.DW.ClientID, ClientSecret: cfg.DW.ClientSecret,
			Timeout: cfg.DW.HTTPTimeout, TokenRequestsPerHour: cfg.DW.TokenRequestsPerHour, TokenRefreshSkew: cfg.DW.TokenRefreshSkew,
		}, dwclient.WithLogger(logger))
		if err != nil {
			return err
		}
	} else {
		logger.Warn("DW credentials not configured; DW calls disabled")
	}

	// 业务接口 /api/v1：需要数据库、PII 密钥与 JWT 密钥
	var routes []func(*http.ServeMux)
	if cfg.APIReady() && st != nil {
		var sender auth.Sender = auth.DisabledSender{}
		if cfg.OTPDevLog {
			sender = auth.DevLogSender{Logger: logger}
			logger.Warn("OTP_DEV_LOG enabled: OTP codes are written to the log (development only)")
		} else {
			logger.Warn("email provider not configured and OTP_DEV_LOG=false: OTP login will fail")
		}
		authSvc := auth.New(auth.PGRepo{DB: st.DB}, sender, cfg.JWTSecret, cfg.SessionTTL, logger)
		if cfg.OTPDevLog { // 演示固定验证码 000000（config 已禁止 production 开启 OTP_DEV_LOG）
			authSvc.EnableDemoCode()
			logger.Warn("demo OTP enabled: code 000000 is accepted (development only)")
		}
		routes = append(routes, func(mux *http.ServeMux) { authSvc.Routes(mux, apiPrefix) })
	} else {
		logger.Warn("API routes disabled: DATABASE_URL, PII_ENCRYPTION_KEY and JWT_SECRET are all required")
	}

	var pinger func(context.Context) error
	if st != nil {
		pinger = st.Ping
	}
	srv := &http.Server{
		Addr: cfg.HTTPAddr,
		Handler: withAccessLog(logger, withCORS(cfg.CORSAllowedOrigins,
			newMux(healthDeps{env: cfg.Env, version: version, dbPing: pinger, dwConfigured: dw != nil}, routes...))),
		ReadHeaderTimeout: 10 * time.Second,
	}

	errCh := make(chan error, 1)
	go func() {
		logger.Info("http server listening", slog.String("addr", cfg.HTTPAddr), slog.String("env", cfg.Env), slog.String("kyc_mode", string(cfg.KYCMode)))
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			errCh <- err
		}
		close(errCh)
	}()

	select {
	case err := <-errCh:
		return err
	case <-ctx.Done():
	}
	shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	logger.Info("shutting down")
	return srv.Shutdown(shutdownCtx)
}
