// Command dwprobe：沙盒字段写法实验工具（仅 sandbox，开发用）。
//
// 对一个沙盒测试用户依次 PATCH 不同写法的"非 PEP / 非董事"，读取 DW 回显的 politicallyExposed 与 director，
// 只打印这两个布尔值与 HTTP 结果，不打印任何 PII。
//
//	set -a; source .env; set +a; go run ./cmd/dwprobe -user <沙盒测试用户 id>
package main

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"net/http"
	"os"
	"time"

	"github.com/imamura-akira/New_FinX/backend/internal/config"
	"github.com/imamura-akira/New_FinX/backend/internal/dwclient"
)

func main() {
	user := flag.String("user", "", "沙盒测试用户 id")
	flag.Parse()
	cfg, err := config.Load()
	if err != nil || !cfg.DWConfigured() || cfg.Env != "sandbox" || *user == "" {
		fmt.Println("需要 sandbox 环境、DW 凭据与 -user 参数")
		os.Exit(2)
	}
	c, err := dwclient.New(dwclient.Config{
		BaseURL: cfg.DW.BaseURL, AppKey: cfg.DW.AppKey, ClientID: cfg.DW.ClientID, ClientSecret: cfg.DW.ClientSecret,
		Timeout: cfg.DW.HTTPTimeout, TokenRequestsPerHour: cfg.DW.TokenRequestsPerHour, TokenRefreshSkew: cfg.DW.TokenRefreshSkew,
	})
	if err != nil {
		fmt.Println(err)
		os.Exit(2)
	}
	type variant struct {
		name string
		pep  any // nil 表示省略字段
		dir  any
		omit bool
	}
	variants := []variant{
		{name: `字符串 "NULL"（文档示例写法）`, pep: "NULL", dir: "NULL"},
		{name: `空字符串 ""`, pep: "", dir: ""},
		{name: `JSON null`, pep: nil, dir: nil},
		{name: `省略字段`, omit: true},
	}
	for _, v := range variants {
		personal := map[string]any{"birthDay": 7, "birthMonth": 3, "birthYear": 1990, "irsBackupWithholdings": false}
		employment := map[string]any{"status": "EMPLOYED", "broker": false, "company": "Example Corp", "type": "PROFESSIONAL", "position": "ENGINEER"}
		if !v.omit {
			personal["politicallyExposedNames"] = v.pep
			employment["directorOf"] = v.dir
		}
		body := map[string]any{"documents": []map[string]any{
			{"type": "PERSONAL_INFO", "data": personal},
			{"type": "EMPLOYMENT_INFO", "data": employment},
		}}
		ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
		var resp map[string]any
		err := c.Do(ctx, http.MethodPatch, "/users/"+*user, body, &resp)
		cancel()
		if err != nil {
			var ae *dwclient.APIError
			if errors.As(err, &ae) {
				fmt.Printf("%-28s → HTTP %d %s\n", v.name, ae.Status, ae.DWCode)
				continue
			}
			fmt.Printf("%-28s → 失败: %v\n", v.name, err)
			continue
		}
		fmt.Printf("%-28s → 200  politicallyExposed=%v  director=%v\n", v.name, resp["politicallyExposed"], resp["director"])
	}
}
