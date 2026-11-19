// Package marketsim：阶段性虚拟行情引擎（F11，backend-design.md 6.5 节）。
//
// 随机游走：每只标的以 prevClose 为锚，按固定 tick 更新 last = last × (1 + N(0, σ) + κ·(prevClose − last)/prevClose)，
// 日内围绕锚点均值回归；涨跌幅相对 prevClose；bid/ask 按 last ± 1–2 bp 生成。
// 只用于展示，不参与任何资金计算（余额、购买力、可提现一律来自 DW）。
package marketsim

import (
	"math"
	"math/rand"
	"sort"
	"strings"
	"sync"
	"time"
)

// Instrument：标的静态信息。
type Instrument struct {
	Symbol    string
	Name      string
	Exchange  string
	Type      string // STOCK / ETF
	PrevClose float64
	Open      float64 // 初始价（演示数据中的最新价）
}

// Candle：分时 K 线（1 分钟聚合）。
type Candle struct {
	T time.Time `json:"t"`
	O float64   `json:"o"`
	H float64   `json:"h"`
	L float64   `json:"l"`
	C float64   `json:"c"`
}

// Quote：报价快照。
type Quote struct {
	Symbol   string
	Last     float64
	Bid      float64
	Ask      float64
	DayHigh  float64
	DayLow   float64
	PrevClos float64
	Updated  time.Time
}

// Chg / ChgPct：相对 prevClose 的涨跌额与涨跌幅（百分数，如 1.07 表示 +1.07%）。
func (q Quote) Chg() float64    { return q.Last - q.PrevClos }
func (q Quote) ChgPct() float64 { return (q.Last - q.PrevClos) / q.PrevClos * 100 }

// Params：引擎参数。
type Params struct {
	Tick      time.Duration // 默认 2s
	Sigma     float64       // 每 tick 收益率标准差，默认 0.0008
	Reversion float64       // 均值回归强度 κ，默认 0.002
	Seed      int64         // 固定种子（演示可复现）
	History   int           // 启动时预生成的分时根数（让个股页图表不为空），默认 60
	MaxBars   int           // 当日最多保留的分时根数，默认 390（美股常规交易时段分钟数）
}

func (p *Params) defaults() {
	if p.Tick <= 0 {
		p.Tick = 2 * time.Second
	}
	if p.Sigma <= 0 {
		p.Sigma = 0.0008
	}
	if p.Reversion <= 0 {
		p.Reversion = 0.002
	}
	if p.Seed == 0 {
		p.Seed = 20261119
	}
	if p.History <= 0 {
		p.History = 60
	}
	if p.MaxBars <= 0 {
		p.MaxBars = 390
	}
}

type state struct {
	inst    Instrument
	quote   Quote
	candles []Candle
	spread  float64 // 当前 bid/ask 半价差（bp）
}

// Engine：并发安全的内存行情。
type Engine struct {
	mu     sync.RWMutex
	p      Params
	rnd    *rand.Rand
	order  []string
	states map[string]*state
	now    func() time.Time
}

// New 创建引擎并用固定种子初始化（含预生成的分时）。
func New(insts []Instrument, p Params, now func() time.Time) *Engine {
	p.defaults()
	if now == nil {
		now = time.Now
	}
	e := &Engine{p: p, now: now}
	e.reset(insts)
	return e
}

// Reset 用原始种子重置全部价格与 K 线（cmd/demoreset 使用）。
func (e *Engine) Reset() {
	e.mu.Lock()
	insts := make([]Instrument, 0, len(e.order))
	for _, s := range e.order {
		insts = append(insts, e.states[s].inst)
	}
	e.mu.Unlock()
	e.reset(insts)
}

func (e *Engine) reset(insts []Instrument) {
	e.mu.Lock()
	defer e.mu.Unlock()
	e.rnd = rand.New(rand.NewSource(e.p.Seed))
	e.states = map[string]*state{}
	e.order = e.order[:0]
	now := e.now().UTC().Truncate(time.Minute)
	for _, in := range insts {
		in.Symbol = strings.ToUpper(in.Symbol)
		if in.Open <= 0 {
			in.Open = in.PrevClose
		}
		st := &state{inst: in, spread: 1.5}
		// 预生成历史分时：从 prevClose 走向演示初始价，使个股页图表与涨跌幅一致
		price := in.PrevClose
		for i := e.p.History; i > 0; i-- {
			t := now.Add(-time.Duration(i) * time.Minute)
			target := in.PrevClose + (in.Open-in.PrevClose)*float64(e.p.History-i+1)/float64(e.p.History)
			o := price
			c := target * (1 + e.rnd.NormFloat64()*e.p.Sigma*2)
			h := math.Max(o, c) * (1 + math.Abs(e.rnd.NormFloat64())*e.p.Sigma)
			l := math.Min(o, c) * (1 - math.Abs(e.rnd.NormFloat64())*e.p.Sigma)
			st.candles = append(st.candles, Candle{T: t, O: round2(o), H: round2(h), L: round2(l), C: round2(c)})
			price = c
		}
		price = in.Open
		st.quote = Quote{Symbol: in.Symbol, Last: price, PrevClos: in.PrevClose, DayHigh: price, DayLow: price, Updated: e.now().UTC()}
		for _, c := range st.candles {
			st.quote.DayHigh = math.Max(st.quote.DayHigh, c.H)
			st.quote.DayLow = math.Min(st.quote.DayLow, c.L)
		}
		st.setBidAsk()
		e.states[in.Symbol] = st
		e.order = append(e.order, in.Symbol)
	}
}

func (s *state) setBidAsk() {
	half := s.quote.Last * s.spread / 10000
	s.quote.Bid = s.quote.Last - half
	s.quote.Ask = s.quote.Last + half
}

// Step 推进一个 tick：所有标的随机游走一步并聚合到当前分钟 K 线。
func (e *Engine) Step() {
	e.mu.Lock()
	defer e.mu.Unlock()
	now := e.now().UTC()
	minute := now.Truncate(time.Minute)
	for _, sym := range e.order {
		st := e.states[sym]
		q := &st.quote
		r := e.rnd.NormFloat64()*e.p.Sigma + e.p.Reversion*(q.PrevClos-q.Last)/q.PrevClos
		q.Last = math.Max(0.01, q.Last*(1+r))
		q.DayHigh = math.Max(q.DayHigh, q.Last)
		q.DayLow = math.Min(q.DayLow, q.Last)
		q.Updated = now
		st.spread = 1 + e.rnd.Float64() // 1–2 bp
		st.setBidAsk()

		last := round2(q.Last)
		n := len(st.candles)
		if n > 0 && st.candles[n-1].T.Equal(minute) {
			c := &st.candles[n-1]
			c.H, c.L, c.C = math.Max(c.H, last), math.Min(c.L, last), last
		} else {
			open := last
			if n > 0 {
				open = st.candles[n-1].C
			}
			st.candles = append(st.candles, Candle{T: minute, O: open, H: math.Max(open, last), L: math.Min(open, last), C: last})
			if len(st.candles) > e.p.MaxBars {
				st.candles = st.candles[len(st.candles)-e.p.MaxBars:]
			}
		}
	}
}

// Quotes 返回指定代码的报价（未知代码忽略）；symbols 为空时返回全部（按标的池顺序）。
func (e *Engine) Quotes(symbols []string) []Quote {
	e.mu.RLock()
	defer e.mu.RUnlock()
	if len(symbols) == 0 {
		symbols = e.order
	}
	out := make([]Quote, 0, len(symbols))
	seen := map[string]bool{}
	for _, s := range symbols {
		s = strings.ToUpper(strings.TrimSpace(s))
		if st, ok := e.states[s]; ok && !seen[s] {
			seen[s] = true
			out = append(out, st.quote)
		}
	}
	return out
}

// Instrument 返回单个标的的静态信息、报价与当日分时（不存在时 ok=false）。
func (e *Engine) Instrument(symbol string) (Instrument, Quote, []Candle, bool) {
	e.mu.RLock()
	defer e.mu.RUnlock()
	st, ok := e.states[strings.ToUpper(strings.TrimSpace(symbol))]
	if !ok {
		return Instrument{}, Quote{}, nil, false
	}
	return st.inst, st.quote, append([]Candle(nil), st.candles...), true
}

// Symbols 返回标的池（已排序副本）。
func (e *Engine) Symbols() []string {
	e.mu.RLock()
	defer e.mu.RUnlock()
	out := append([]string(nil), e.order...)
	sort.Strings(out)
	return out
}

// Tick 返回 tick 间隔。
func (e *Engine) Tick() time.Duration { return e.p.Tick }

func round2(f float64) float64 { return math.Round(f*100) / 100 }
