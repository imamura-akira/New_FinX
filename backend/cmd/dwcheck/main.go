// Command dwcheck 用当前环境变量中的 DW 凭据申请一次 token，只报告结果，不打印 token 或任何凭据。
//
//	set -a; source .env; set +a; go run ./cmd/dwcheck
//
// 每次运行消耗 1 次 token 请求预算（DW 约 5–10 次/小时），请勿频繁运行。
package main

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"os"
	"time"

	"github.com/imamura-akira/New_FinX/backend/internal/config"
	"github.com/imamura-akira/New_FinX/backend/internal/dwclient"
)

func main() {
	os.Exit(run())
}

func run() int {
	cfg, err := config.Load()
	if err != nil {
		fmt.Println("配置错误:", err)
		return 2
	}
	if !cfg.DWConfigured() {
		fmt.Println("DW 凭据不完整（DW_APP_KEY / DW_CLIENT_ID / DW_CLIENT_SECRET 需全部填写）")
		return 2
	}
	logger := slog.New(slog.NewJSONHandler(os.Stderr, nil))
	c, err := dwclient.New(dwclient.Config{
		BaseURL: cfg.DW.BaseURL, AppKey: cfg.DW.AppKey, ClientID: cfg.DW.ClientID, ClientSecret: cfg.DW.ClientSecret,
		Timeout: cfg.DW.HTTPTimeout, TokenRequestsPerHour: cfg.DW.TokenRequestsPerHour, TokenRefreshSkew: cfg.DW.TokenRefreshSkew,
		LogBodies: cfg.DW.LogBodies,
	}, dwclient.WithLogger(logger))
	if err != nil {
		fmt.Println("创建 DW 客户端失败:", err)
		return 2
	}
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	tok, err := c.Token(ctx)
	if err != nil {
		var apiErr *dwclient.APIError
		if errors.As(err, &apiErr) {
			fmt.Printf("结果：失败，HTTP %d（DW code=%q, requestId=%q）\n", apiErr.Status, apiErr.DWCode, apiErr.RequestID)
			if apiErr.Status == 401 {
				fmt.Println("提示：401 = 凭据被拒绝，请核对 DW_CLIENT_ID / DW_CLIENT_SECRET / DW_APP_KEY")
			}
			return 1
		}
		fmt.Println("结果：失败（非 HTTP 错误）:", err)
		return 1
	}
	fmt.Printf("结果：成功，HTTP 2xx，已获得 token（长度 %d，内容不显示）\n", len(tok))
	return 0
}
