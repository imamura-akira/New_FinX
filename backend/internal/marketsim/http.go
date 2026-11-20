package marketsim

import (
	"context"
	"net/http"
	"strings"
	"time"

	"github.com/imamura-akira/New_FinX/backend/internal/httpx"
)

// DefaultInstruments：标的池，取自原型演示数据（prototype/js/data.js 的 P-09 列表与演示自选），
// 名称、交易所、昨收与初始价与原型一致，便于 App 与原型对照。全部为演示用虚拟行情。
var DefaultInstruments = []Instrument{
	{"AAPL", "Apple Inc.", "NASDAQ", "STOCK", 226.10, 228.52},
	{"MSFT", "Microsoft Corp.", "NASDAQ", "STOCK", 418.02, 415.30},
	{"NVDA", "NVIDIA Corp.", "NASDAQ", "STOCK", 129.40, 132.85},
	{"AMZN", "Amazon.com Inc.", "NASDAQ", "STOCK", 199.80, 201.12},
	{"GOOGL", "Alphabet Inc. Cl A", "NASDAQ", "STOCK", 173.95, 172.40},
	{"TSLA", "Tesla Inc.", "NASDAQ", "STOCK", 241.20, 248.60},
	{"META", "Meta Platforms Inc.", "NASDAQ", "STOCK", 560.00, 563.10},
	{"JPM", "JPMorgan Chase & Co.", "NYSE", "STOCK", 222.90, 221.75},
	{"KO", "Coca-Cola Co.", "NYSE", "STOCK", 63.05, 63.20},
	{"DIS", "Walt Disney Co.", "NYSE", "STOCK", 110.10, 112.40},
	{"NFLX", "Netflix Inc.", "NASDAQ", "STOCK", 752.00, 760.50},
	{"AMD", "Advanced Micro Devices", "NASDAQ", "STOCK", 149.80, 145.20},
	{"SPY", "SPDR S&P 500 ETF", "NYSE Arca", "ETF", 592.00, 590.20},
	{"QQQ", "Invesco QQQ Trust", "NASDAQ", "ETF", 508.70, 505.40},
	{"DIA", "SPDR Dow Jones Industrial ETF", "NYSE Arca", "ETF", 440.90, 438.10},
	{"IWM", "iShares Russell 2000 ETF", "NYSE Arca", "ETF", 226.90, 228.30},
	{"GLD", "SPDR Gold Shares", "NYSE Arca", "ETF", 241.20, 245.60},
	{"SLV", "iShares Silver Trust", "NYSE Arca", "ETF", 28.50, 29.40},
	{"USO", "United States Oil Fund", "NYSE Arca", "ETF", 75.40, 76.20},
	{"TLT", "iShares 20+ Year Treasury Bond ETF", "NASDAQ", "ETF", 92.60, 92.10},
	{"XLK", "Technology Select Sector SPDR", "NYSE Arca", "ETF", 230.10, 232.30},
	{"XLE", "Energy Select Sector SPDR", "NYSE Arca", "ETF", 91.80, 91.00},
	{"EEM", "iShares MSCI Emerging Markets ETF", "NYSE Arca", "ETF", 42.90, 43.40},
	{"VXX", "iPath S&P 500 VIX ST Futures ETN", "CBOE", "ETF", 49.60, 48.00},
}

// maxSymbolsPerRequest：单次批量报价的代码上限。
const maxSymbolsPerRequest = 50

// Start 按 tick 推进行情，直到 ctx 结束。
func (e *Engine) Start(ctx context.Context) {
	t := time.NewTicker(e.p.Tick)
	defer t.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-t.C:
			e.Step()
		}
	}
}

// Routes 注册 /market/*（api-spec.md 5.5）。行情为模拟数据、不含用户信息，
// P-01"先逛逛行情"需未登录可看，因此不要求会话（api-spec.md 第 10 节登记）。
func (e *Engine) Routes(mux *http.ServeMux, prefix string) {
	mux.HandleFunc("GET "+prefix+"/market/quotes", e.handleQuotes)
	mux.HandleFunc("GET "+prefix+"/market/instruments/{symbol}", e.handleInstrument)
	mux.HandleFunc("GET "+prefix+"/market/sentiment", e.handleSentiment)
}

// handleSentiment：P-09 市场情绪卡（恐慌贪婪指数 + 涨跌家数），演示数据。
func (e *Engine) handleSentiment(w http.ResponseWriter, r *http.Request) {
	s := e.Sentiment()
	ts := s.Updated
	if ts.IsZero() {
		ts = e.now().UTC()
	}
	httpx.OK(w, map[string]any{
		"simulated": true,
		"ts":        ts,
		"fearGreed": map[string]any{"value": s.FearGreed, "label": s.Label, "components": s.Components},
		"breadth": map[string]any{
			"up": s.Breadth.Up, "down": s.Breadth.Down, "flat": s.Breadth.Flat, "total": s.Breadth.Total,
			"flatThresholdPct": FlatThresholdPct,
		},
	})
}

type quoteView struct {
	Symbol string  `json:"symbol"`
	Last   float64 `json:"last"`
	Chg    float64 `json:"chg"`
	ChgPct float64 `json:"chgPct"`
	Bid    float64 `json:"bid"`
	Ask    float64 `json:"ask"`
}

func view(q Quote) quoteView {
	return quoteView{Symbol: q.Symbol, Last: round2(q.Last), Chg: round2(q.Chg()), ChgPct: round2(q.ChgPct()), Bid: round2(q.Bid), Ask: round2(q.Ask)}
}

func (e *Engine) handleQuotes(w http.ResponseWriter, r *http.Request) {
	var symbols []string
	if raw := strings.TrimSpace(r.URL.Query().Get("symbols")); raw != "" {
		for _, s := range strings.Split(raw, ",") {
			if s = strings.TrimSpace(s); s != "" {
				symbols = append(symbols, s)
			}
		}
		if len(symbols) > maxSymbolsPerRequest {
			httpx.Fail(w, r, httpx.Validation("", httpx.FieldError{Field: "symbols", Reason: "一次最多查询 50 个代码"}))
			return
		}
	}
	qs := e.Quotes(symbols)
	out := make([]quoteView, 0, len(qs))
	ts := time.Time{}
	for _, q := range qs {
		out = append(out, view(q))
		if q.Updated.After(ts) {
			ts = q.Updated
		}
	}
	if ts.IsZero() {
		ts = e.now().UTC()
	}
	httpx.OK(w, map[string]any{"simulated": true, "ts": ts, "quotes": out})
}

func (e *Engine) handleInstrument(w http.ResponseWriter, r *http.Request) {
	in, q, candles, ok := e.Instrument(r.PathValue("symbol"))
	if !ok {
		httpx.Fail(w, r, httpx.Validation("", httpx.FieldError{Field: "symbol", Reason: "暂不支持该证券代码"}))
		return
	}
	v := view(q)
	httpx.OK(w, map[string]any{
		"simulated": true,
		"symbol":    in.Symbol,
		"name":      in.Name,
		"exchange":  in.Exchange, // 新增字段（P-10 展示）
		"type":      in.Type,     // 新增字段：STOCK / ETF
		"last":      v.Last,
		"chg":       v.Chg,
		"chgPct":    v.ChgPct,
		"dayHigh":   round2(q.DayHigh),
		"dayLow":    round2(q.DayLow),
		"prevClose": round2(q.PrevClos),
		"candles":   candles,
	})
}
