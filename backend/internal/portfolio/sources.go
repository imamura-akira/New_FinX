package portfolio

import (
	"context"
	"encoding/json"
	"log/slog"
	"math"
	"net/http"
	"strconv"

	"github.com/imamura-akira/New_FinX/backend/internal/account"
)

// DW：所需的 DW 能力（*dwclient.Client 满足）。
type DW interface {
	Do(ctx context.Context, method, path string, reqBody, out any) error
}

// dwMoney：GET /accounts/{id}/summary/money，只取 cash.cashBalance（与 GET /account/money 的 cash 同源）。
type dwMoney struct {
	Cash struct {
		CashBalance json.Number `json:"cashBalance"`
	} `json:"cash"`
}

// dwPositions：GET /accounts/{id}/summary/positions，只取代码、持仓数量与市值。
type dwPositions struct {
	EquityPositions []struct {
		Symbol      string  `json:"symbol"`
		OpenQty     float64 `json:"openQty"`
		MarketValue float64 `json:"marketValue"`
	} `json:"equityPositions"`
}

func toCents(f float64) int64 { return int64(math.Round(f * 100)) }

// DWSource：实盘资产构成，全部取 DW 返回值（现金 + 各持仓市值），按 classify 归类。
func DWSource(dw DW, acct func(ctx context.Context, userID string) (*account.Account, error), classify func(string) string, logger *slog.Logger) Source {
	return func(ctx context.Context, userID string) (Breakdown, error) {
		a, err := acct(ctx, userID)
		if err != nil {
			return Breakdown{}, err
		}
		if a == nil || a.DWAccountID == "" {
			return Breakdown{}, ErrNotOpened
		}
		var m dwMoney
		if err := dw.Do(ctx, http.MethodGet, "/accounts/"+a.DWAccountID+"/summary/money", nil, &m); err != nil {
			return Breakdown{}, err
		}
		var p dwPositions
		if err := dw.Do(ctx, http.MethodGet, "/accounts/"+a.DWAccountID+"/summary/positions", nil, &p); err != nil {
			return Breakdown{}, err
		}
		cash, _ := strconv.ParseFloat(m.Cash.CashBalance.String(), 64)
		hs := make([]Holding, 0, len(p.EquityPositions))
		for _, e := range p.EquityPositions {
			if e.OpenQty == 0 {
				continue
			}
			hs = append(hs, Holding{Symbol: e.Symbol, Value: toCents(e.MarketValue)})
		}
		return Group(toCents(cash), hs, classify), nil
	}
}

// PaperSource：模拟盘资产构成（holdings 返回模拟账户现金与各持仓市值，单位分）。
func PaperSource(holdings func(ctx context.Context, userID string) (int64, []Holding, error), classify func(string) string) Source {
	return func(ctx context.Context, userID string) (Breakdown, error) {
		cash, hs, err := holdings(ctx, userID)
		if err != nil {
			return Breakdown{}, err
		}
		return Group(cash, hs, classify), nil
	}
}
