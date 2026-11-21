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

	"github.com/imamura-akira/New_FinX/backend/internal/account"
	"github.com/imamura-akira/New_FinX/backend/internal/application"
	"github.com/imamura-akira/New_FinX/backend/internal/auth"
	"github.com/imamura-akira/New_FinX/backend/internal/config"
	"github.com/imamura-akira/New_FinX/backend/internal/crypto"
	"github.com/imamura-akira/New_FinX/backend/internal/dwclient"
	"github.com/imamura-akira/New_FinX/backend/internal/events"
	"github.com/imamura-akira/New_FinX/backend/internal/funding"
	"github.com/imamura-akira/New_FinX/backend/internal/httpx"
	"github.com/imamura-akira/New_FinX/backend/internal/marketsim"
	"github.com/imamura-akira/New_FinX/backend/internal/papertrade"
	"github.com/imamura-akira/New_FinX/backend/internal/portfolio"
	"github.com/imamura-akira/New_FinX/backend/internal/predict"
	"github.com/imamura-akira/New_FinX/backend/internal/store"
	"github.com/imamura-akira/New_FinX/backend/internal/trading"
)

// version 可在构建时用 -ldflags "-X main.version=..." 注入。
var version = "dev"

func main() {
	// api-spec.md：时间一律 ISO-8601 UTC。数据库驱动按进程本地时区解码 timestamptz，统一设为 UTC。
	time.Local = time.UTC
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
			LogBodies: cfg.DW.LogBodies,
		}, dwclient.WithLogger(logger))
		if err != nil {
			return err
		}
	} else {
		logger.Warn("DW credentials not configured; DW calls disabled")
	}

	// 业务接口 /api/v1：需要数据库、PII 密钥与 JWT 密钥
	var routes []func(*http.ServeMux)

	// F11 虚拟行情：不依赖数据库与 DW，始终可用（MARKET_DATA_MODE=REAL 时未挂载，接口返回 50003）
	var market *marketsim.Engine
	if cfg.MarketDataMode == config.MarketSim {
		market = marketsim.New(marketsim.DefaultInstruments, marketsim.Params{Tick: cfg.MarketTick}, nil)
		go market.Start(ctx)
		routes = append(routes, func(mux *http.ServeMux) { market.Routes(mux, apiPrefix) })
		logger.Info("market simulator started", slog.Int("instruments", len(marketsim.DefaultInstruments)), slog.Duration("tick", cfg.MarketTick))
	}
	if cfg.APIReady() && st != nil {
		var sender auth.Sender = auth.DisabledSender{}
		if cfg.OTPDevLog {
			sender = auth.DevLogSender{Logger: logger}
			logger.Warn("OTP_DEV_LOG enabled: OTP codes are written to the log (development only)")
		} else {
			logger.Warn("email provider not configured and OTP_DEV_LOG=false: OTP login will fail")
		}
		httpx.SetTrustedProxies(cfg.TrustedProxies) // 限速按真实客户端 IP（审计 SEC-P1-1）
		if len(cfg.TrustedProxies) > 0 {
			logger.Info("trusted proxies configured", slog.Int("entries", len(cfg.TrustedProxies)))
		}
		authSvc := auth.New(auth.PGRepo{DB: st.DB}, sender, cfg.JWTSecret, cfg.SessionTTL, logger)
		if len(cfg.AllowedEmails) > 0 {
			authSvc.SetAllowedEmails(cfg.AllowedEmails)
			logger.Info("login email allowlist enabled", slog.Int("entries", len(cfg.AllowedEmails)))
		}
		// 固定验证码 000000：仅演示环境，生产禁止（config 校验），接入邮件服务后移除（审计 SEC-P0-1，用户已知悉并接受）
		if cfg.OTPFixedCode {
			authSvc.EnableDemoCode()
			logger.Warn("OTP_FIXED_CODE enabled: code 000000 is accepted (demo only; remove after email provider is integrated)")
		}
		cipher, err := crypto.New(cfg.PIIKey)
		if err != nil {
			return err
		}
		appRepo := application.PGRepo{DB: st.DB}
		appSvc := application.New(appRepo, cipher, logger)
		var dwAPI account.DW
		if dw != nil {
			dwAPI = dw
		}
		acctRepo := account.PGRepo{DB: st.DB}
		acctSvc := account.New(acctRepo, dwAPI, logger)
		if cfg.OTPDevLog { // 演示环境：GET /account 附带 DW 编号供 App 对照（config 已禁止 production 开启 OTP_DEV_LOG）
			acctSvc.SetExposeDWIdentifiers(true)
		}
		var fundSvc *funding.Service
		if dw != nil {
			fundSvc = funding.New(funding.Deps{
				Repo: funding.PGRepo{DB: st.DB}, DW: dw, Cipher: cipher,
				Account: acctRepo.ForUser, LegalName: appSvc.LegalName,
				Limits: cfg.Limits, BankLink: cfg.BankLinkMethod, Logger: logger,
			})
		}
		// F15 模拟盘：只依赖数据库与虚拟行情，不调 DW（DW 未配置时也可用）
		var paperSvc *papertrade.Service
		if market != nil {
			paperSvc = papertrade.New(papertrade.Deps{
				Repo: papertrade.PGRepo{DB: st.DB},
				Quote: func(sym string) (papertrade.Quote, bool) {
					q := market.Quotes([]string{sym})
					if len(q) == 0 || isCrypto(sym) { // 加密标的只用于 F19 积分预测，不可交易
						return papertrade.Quote{}, false
					}
					return papertrade.Quote{Bid: q[0].Bid, Ask: q[0].Ask, Last: q[0].Last}, true
				},
				PrevClose: func(sym string) float64 {
					q := market.Quotes([]string{sym})
					if len(q) == 0 {
						return 0
					}
					return q[0].PrevClos
				},
				InitialCash: cfg.PaperInitialCash, MinOrder: cfg.Limits.MinOrder, Logger: logger,
			})
			go paperSvc.RunMatcher(ctx, cfg.MarketTick)
			logger.Info("paper trading enabled", slog.Float64("initial_cash", cfg.PaperInitialCash))
		}
		var tradeSvc *trading.Service
		if dw != nil { // F14 交易：按股数买入时用演示行情估算金额（REAL 模式未接入前无报价，只能按金额买入）
			var price func(string) (float64, bool)
			if market != nil {
				price = func(sym string) (float64, bool) {
					q := market.Quotes([]string{sym})
					if len(q) == 0 || isCrypto(sym) {
						return 0, false
					}
					if q[0].Ask > 0 {
						return q[0].Ask, true
					}
					return q[0].Last, q[0].Last > 0
				}
			}
			tradeSvc = trading.New(trading.Deps{
				Repo: trading.PGRepo{DB: st.DB}, DW: dw, Account: acctRepo.ForUser, Price: price,
				MinOrder: cfg.Limits.MinOrder, PreventQueuing: cfg.TradePreventQueuing, Logger: logger,
			})
		}
		// F17 资产分布与每日快照：实盘依赖 DW，模拟盘依赖模拟账户；按我方标的列表归类（列表外按股票计）
		classify := func(sym string) string {
			if t, ok := marketsim.InstrumentType(sym); ok && t == "ETF" {
				return portfolio.TypeETF
			}
			return portfolio.TypeStock
		}
		pfDeps := portfolio.Deps{Repo: portfolio.PGRepo{DB: st.DB}, Logger: logger}
		if dw != nil {
			pfDeps.Real = portfolio.DWSource(dw, acctRepo.ForUser, classify, logger)
		}
		if paperSvc != nil {
			pfDeps.Paper = portfolio.PaperSource(func(ctx context.Context, uid string) (int64, []portfolio.Holding, error) {
				cash, vals, err := paperSvc.Holdings(ctx, uid)
				hs := make([]portfolio.Holding, 0, len(vals))
				for sym, v := range vals {
					hs = append(hs, portfolio.Holding{Symbol: sym, Value: v})
				}
				return cash, hs, err
			}, classify)
		}
		pfSvc := portfolio.New(pfDeps)
		go pfSvc.Run(ctx, 5*time.Minute)
		// F19 预测板块（积分演示版）：只依赖数据库与虚拟行情，与券商资金、模拟盘完全隔离
		var predictSvc *predict.Service
		if market != nil {
			predictSvc = predict.New(predict.Deps{
				Repo: predict.PGRepo{DB: st.DB},
				Price: func(sym string) (float64, bool) {
					q := market.Quotes([]string{sym})
					if len(q) == 0 {
						return 0, false
					}
					return q[0].Last, true
				},
				Logger: logger,
			})
			go predictSvc.Run(ctx, 5*time.Second)
		}
		if dw != nil {
			rec := events.NewReconciler(events.PGRepo{DB: st.DB}, dw, acctSvc, cfg.KYCPollInterval, logger)
			orch := application.NewOrchestrator(appRepo, dw, cipher, cfg.UserSubmitMode, logger)
			orch.OnUserCreated = rec.RefreshApp // DW User 创建后立即查一次 KYC
			rec.AddJob(func(ctx context.Context) { fundSvc.Sync(ctx, cfg.KYCPollInterval) })
			rec.AddJob(func(ctx context.Context) { tradeSvc.Sync(ctx, cfg.KYCPollInterval) })
			appSvc.WithOrchestrator(orch, appRepo, cfg.KYCMode)
			go orch.Start(ctx, time.Minute) // 后台续传未完成的提交
			go rec.Start(ctx)               // KYC / 开户 / 账户状态对账
			logger.Info("dw reconciler started", slog.Duration("interval", cfg.KYCPollInterval))
		} else {
			logger.Warn("application submit and DW sync disabled: DW credentials not configured")
		}
		routes = append(routes, func(mux *http.ServeMux) {
			authSvc.Routes(mux, apiPrefix)
			appSvc.Routes(mux, apiPrefix, authSvc.RequireAuth)
			acctSvc.Routes(mux, apiPrefix, authSvc.RequireAuth)
			if fundSvc != nil {
				fundSvc.Routes(mux, apiPrefix, authSvc.RequireAuth)
			}
			if tradeSvc != nil {
				tradeSvc.Routes(mux, apiPrefix, authSvc.RequireAuth)
			}
			if paperSvc != nil {
				paperSvc.Routes(mux, apiPrefix, authSvc.RequireAuth)
			}
			pfSvc.Routes(mux, apiPrefix, authSvc.RequireAuth)
			if predictSvc != nil {
				predictSvc.Routes(mux, apiPrefix, authSvc.RequireAuth)
			}
		})
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

// isCrypto：F19 模拟加密标的（BTC / SOL）只用于积分预测，实盘与模拟盘下单均不报价。
func isCrypto(sym string) bool {
	t, ok := marketsim.InstrumentType(sym)
	return ok && t == "CRYPTO"
}
