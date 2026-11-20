package marketsim

import (
	"math"
	"time"
)

// 市场情绪（F11 扩展，api-spec.md 5.5 GET /market/sentiment）。全部基于虚拟行情，仅用于展示（演示数据）。
//
// 恐慌贪婪指数（0–100）由四个分量加权合成，再做指数平滑使其缓慢变化：
//   - 涨跌家数（30%）：50 + 50 ×（上涨 − 下跌）/ 总数
//   - 平均涨跌幅（30%）：50 + 25 × 平均涨跌幅（%），±2% 封顶
//   - 动量（20%）：50 + 100 × 近 10 根分时的平均涨幅（%），±0.5% 封顶
//   - 波动（20%）：50 − 100 ×（近 10 根分时平均振幅% − 0.55）− 5 × VXX 涨跌幅（%）；波动越大越偏恐慌
// 平均涨跌幅与动量不含 VXX（反向波动率产品）；涨跌家数统计全部标的。
// 正式数据源待定（自行计算或采购，不得抓取第三方指数）。

// FlatThresholdPct：涨跌幅绝对值小于该值（百分数）计为平盘。
const FlatThresholdPct = 0.10

// sentimentAlpha：每个 tick 向最新合成值靠拢的比例（指数平滑，使指数缓慢变化）。
const sentimentAlpha = 0.08

const momentumBars = 10

// volBaselinePct：近 10 根 1 分钟分时平均振幅的基准（默认参数下实测约 0.55%）。
const volBaselinePct = 0.55

// 波动率分量参考的反向产品。
const volSymbol = "VXX"

// FearGreed 档位代码（App 显示中文：极度恐慌 / 恐慌 / 中性 / 贪婪 / 极度贪婪）。
const (
	ExtremeFear  = "EXTREME_FEAR"
	Fear         = "FEAR"
	Neutral      = "NEUTRAL"
	Greed        = "GREED"
	ExtremeGreed = "EXTREME_GREED"
)

// FearGreedLabel：0–24 极度恐慌，25–44 恐慌，45–55 中性，56–75 贪婪，76–100 极度贪婪。
func FearGreedLabel(v int) string {
	switch {
	case v <= 24:
		return ExtremeFear
	case v <= 44:
		return Fear
	case v <= 55:
		return Neutral
	case v <= 75:
		return Greed
	default:
		return ExtremeGreed
	}
}

// Components：各分量得分（0–100）。
type Components struct {
	Breadth    float64 `json:"breadth"`
	Change     float64 `json:"change"`
	Momentum   float64 `json:"momentum"`
	Volatility float64 `json:"volatility"`
}

// Breadth：涨跌家数。
type Breadth struct {
	Up    int `json:"up"`
	Down  int `json:"down"`
	Flat  int `json:"flat"`
	Total int `json:"total"`
}

// Sentiment：情绪快照。
type Sentiment struct {
	FearGreed  int
	Label      string
	Components Components
	Breadth    Breadth
	Updated    time.Time
}

func clamp100(v float64) float64 { return math.Max(0, math.Min(100, v)) }

// CountBreadth 按涨跌幅（百分数）统计涨跌家数；|涨跌幅| < FlatThresholdPct 计为平盘。
func CountBreadth(chgPcts []float64) Breadth {
	b := Breadth{Total: len(chgPcts)}
	for _, p := range chgPcts {
		switch {
		case math.Abs(p) < FlatThresholdPct:
			b.Flat++
		case p > 0:
			b.Up++
		default:
			b.Down++
		}
	}
	return b
}

// measure 计算当前涨跌家数与各分量（调用方持锁）。
func (e *Engine) measure() (Breadth, Components, float64) {
	pcts := make([]float64, 0, len(e.order))
	var sumChg, sumMom, sumRange float64
	var n, nr int
	vxx, hasVxx := 0.0, false
	for _, sym := range e.order {
		st := e.states[sym]
		q := st.quote
		pct := round2(q.ChgPct())
		pcts = append(pcts, pct)
		if sym == volSymbol {
			vxx, hasVxx = pct, true
			continue
		}
		sumChg += pct
		if k := len(st.candles); k > 0 {
			ref := st.candles[max(0, k-1-momentumBars)].C
			if ref > 0 {
				sumMom += (q.Last - ref) / ref * 100
			}
			for _, cd := range st.candles[max(0, k-momentumBars):] {
				if cd.C > 0 {
					sumRange += (cd.H - cd.L) / cd.C * 100
					nr++
				}
			}
		}
		n++
	}
	b := CountBreadth(pcts)
	c := Components{Breadth: 50, Change: 50, Momentum: 50, Volatility: 50}
	if b.Total > 0 {
		c.Breadth = clamp100(50 + 50*float64(b.Up-b.Down)/float64(b.Total))
	}
	if n > 0 {
		c.Change = clamp100(50 + 25*sumChg/float64(n))
		c.Momentum = clamp100(50 + 100*sumMom/float64(n))
	}
	vol := 50.0
	if nr > 0 {
		vol -= 100 * (sumRange/float64(nr) - volBaselinePct)
	}
	if hasVxx {
		vol -= 5 * vxx
	}
	c.Volatility = clamp100(vol)
	raw := 0.3*c.Breadth + 0.3*c.Change + 0.2*c.Momentum + 0.2*c.Volatility
	return b, c, raw
}

// updateSentiment 每个 tick 调用（调用方持写锁）：指数平滑向最新合成值靠拢。
func (e *Engine) updateSentiment(init bool) {
	_, _, raw := e.measure()
	if init {
		e.fearGreed = raw
		return
	}
	e.fearGreed += sentimentAlpha * (raw - e.fearGreed)
}

// Sentiment 返回当前市场情绪快照。
func (e *Engine) Sentiment() Sentiment {
	e.mu.RLock()
	defer e.mu.RUnlock()
	b, c, _ := e.measure()
	v := int(math.Round(clamp100(e.fearGreed)))
	ts := time.Time{}
	for _, sym := range e.order {
		if u := e.states[sym].quote.Updated; u.After(ts) {
			ts = u
		}
	}
	round1 := func(f float64) float64 { return math.Round(f*10) / 10 }
	c = Components{Breadth: round1(c.Breadth), Change: round1(c.Change), Momentum: round1(c.Momentum), Volatility: round1(c.Volatility)}
	return Sentiment{FearGreed: v, Label: FearGreedLabel(v), Components: c, Breadth: b, Updated: ts}
}
