// Command predictctl：F19 预测板块（积分演示版）管理命令——事件市场人工结算。
//
//	go run ./cmd/predictctl list                    列出未结算的事件市场（含已截止待结算）
//	go run ./cmd/predictctl settle <市场ID> YES|NO|VOID   结算事件市场：命中者可领取派彩，VOID 退回本金
//
// 15 分钟涨跌市场由后端按虚拟行情自动结算，无需本命令。只能在 APP_ENV=sandbox 下运行。
package main

import (
	"context"
	"fmt"
	"os"
	"strings"
	"time"

	"github.com/imamura-akira/New_FinX/backend/internal/config"
	"github.com/imamura-akira/New_FinX/backend/internal/predict"
	"github.com/imamura-akira/New_FinX/backend/internal/store"
)

func fail(format string, a ...any) {
	fmt.Fprintf(os.Stderr, format+"\n", a...)
	os.Exit(1)
}

func main() {
	if len(os.Args) < 2 {
		fail("用法：predictctl list | predictctl settle <市场ID> YES|NO|VOID")
	}
	cfg, err := config.Load()
	if err != nil {
		fail("配置无效：%v", err)
	}
	if cfg.Env != "sandbox" {
		fail("predictctl 只能在 APP_ENV=sandbox 下运行")
	}
	if cfg.DatabaseURL == "" {
		fail("需要 DATABASE_URL")
	}
	ctx, cancel := context.WithTimeout(context.Background(), time.Minute)
	defer cancel()
	st, err := store.Open(ctx, cfg.DatabaseURL)
	if err != nil {
		fail("数据库连接失败：%v", err)
	}
	defer st.Close()
	repo := predict.PGRepo{DB: st.DB}
	switch os.Args[1] {
	case "list":
		rows, err := st.DB.QueryContext(ctx, `SELECT id, category, closes_at, pool_yes, pool_no, title_zh FROM predict_markets
			WHERE kind = 'EVENT' AND result IS NULL ORDER BY sort_order`)
		if err != nil {
			fail("查询失败：%v", err)
		}
		defer rows.Close()
		fmt.Printf("%-16s %-9s %-17s %5s  %s\n", "ID", "CATEGORY", "CLOSES (UTC)", "YES%", "TITLE")
		for rows.Next() {
			var id, cat, title string
			var closes time.Time
			var py, pn int64
			if err := rows.Scan(&id, &cat, &closes, &py, &pn, &title); err != nil {
				fail("读取失败：%v", err)
			}
			fmt.Printf("%-16s %-9s %-17s %4d%%  %s\n", id, cat, closes.UTC().Format("2006-01-02 15:04"), predict.PercentYes(py, pn), title)
		}
	case "settle":
		if len(os.Args) != 4 {
			fail("用法：predictctl settle <市场ID> YES|NO|VOID")
		}
		id, res := os.Args[2], strings.ToUpper(os.Args[3])
		if res != predict.Yes && res != predict.No && res != predict.Void {
			fail("结果只能是 YES / NO / VOID")
		}
		m, err := repo.GetMarket(ctx, id)
		if err != nil || m == nil {
			fail("市场不存在：%s", id)
		}
		if m.Kind != predict.KindEvent {
			fail("15 分钟涨跌市场由后端自动结算")
		}
		n, err := repo.Settle(ctx, id, res, nil, time.Now().UTC())
		if err != nil {
			fail("结算失败：%v", err)
		}
		fmt.Printf("已结算 %s → %s，涉及 %d 笔下注（用户在\"我的预测\"中领取）\n", id, res, n)
	default:
		fail("未知命令 %q", os.Args[1])
	}
}
