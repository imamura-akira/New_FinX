// Package predict：预测板块（F19，积分演示版，api-spec.md 5.9 /predict/*）。
//
// 全程使用预测积分（每用户初始 10,000 分），不涉及真实资金、券商账户与模拟盘账户，数据独立存储（predict_* 表）。
//   - 市场：UPDOWN（BTC / SOL 15 分钟涨跌，按虚拟行情自动结算）与 EVENT（事件，后端管理命令 cmd/predictctl 结算）。
//   - 定价（简化模型）：按下注时双边池子的比例定赔率——选中方向的概率 p = 该方向池 ÷ 两边池之和（含种子流动性），
//     若正确可得 floor(下注 ÷ p) 分（含本金）；下注后池子增加，比例随双边下注量实时变化。AMM / 订单簿定价留二期。
//   - 结算：UPDOWN 收盘价 > 目标价为"上涨"（YES），< 为"下跌"（NO），相等作废退回；EVENT 由管理命令判定 YES / NO / VOID。
//     结算后命中的下注可领取 potential_payout，作废的可领回本金，未命中为 0。
package predict

import (
	"errors"
	"math"
	"time"
)

// 常量。
const (
	InitialPoints = 10000
	MinStake      = 10
	MaxStake      = 5000
	Window        = 15 * time.Minute
	// 概率夹在 [2%, 98%]，单注赔率最高 50 倍。
	minProb = 0.02
	maxProb = 0.98
	// UPDOWN 每个窗口的种子流动性（两边各 500 分，初始 50% / 50%）。
	UpDownSeed = 500
)

// 市场类型与结果。
const (
	KindUpDown = "UPDOWN"
	KindEvent  = "EVENT"
	Yes        = "YES"
	No         = "NO"
	Void       = "VOID"
)

// 下注状态。
const (
	BetOpen = "OPEN"
	BetWon  = "WON"
	BetLost = "LOST"
	BetVoid = "VOID"
)

// UpDownSymbols：15 分钟市场的标的。
var UpDownSymbols = []string{"BTC", "SOL"}

// Categories：分类（App 标签：全部 / 加密 / 美股 / 宏观 / 体育 / 热点）。
var Categories = []string{"CRYPTO", "STOCKS", "MACRO", "SPORTS", "TRENDING"}

// Market：预测市场。
type Market struct {
	ID, Kind, Category       string
	Symbol                   *string
	TitleZh, TitleEn         string
	SubtitleZh, SubtitleEn   string
	YesZh, YesEn, NoZh, NoEn string
	SeedYes, SeedNo          int64
	PoolYes, PoolNo          int64
	OpensAt, ClosesAt        time.Time
	TargetPrice              *float64
	SettlePrice              *float64
	Result                   *string
	SettledAt                *time.Time
	SortOrder                int
}

// Bet：下注。
type Bet struct {
	ID, UserID, MarketID string
	Outcome              string
	Stake                int64
	Probability          float64
	PotentialPayout      int64
	Status               string
	Payout               int64
	ClaimedAt            *time.Time
	CreatedAt            time.Time
	SettledAt            *time.Time
}

// ProbYes：YES 一方的概率（0–1）。
func ProbYes(poolYes, poolNo int64) float64 {
	if poolYes+poolNo <= 0 {
		return 0.5
	}
	return float64(poolYes) / float64(poolYes+poolNo)
}

// Prob：指定方向的概率。
func (m Market) Prob(outcome string) float64 {
	p := ProbYes(m.PoolYes, m.PoolNo)
	if outcome == No {
		return 1 - p
	}
	return p
}

// Payout：按概率 p 下注 stake，若正确可得的积分（含本金）。p 夹在 [2%, 98%]。
func Payout(stake int64, p float64) int64 {
	p = math.Max(minProb, math.Min(maxProb, p))
	return int64(math.Floor(float64(stake)/p + 1e-9))
}

// PercentYes：YES 百分比整数（0–100），与 App 显示一致（四舍五入，两边合计 100）。
func PercentYes(poolYes, poolNo int64) int {
	return int(math.Round(ProbYes(poolYes, poolNo) * 100))
}

// 错误。
var (
	ErrMarketClosed = errors.New("market closed")
	ErrBadOutcome   = errors.New("bad outcome")
	ErrStake        = errors.New("bad stake")
	ErrInsufficient = errors.New("insufficient points")
	ErrNotFound     = errors.New("not found")
	ErrSettled      = errors.New("already settled")
)

// Open：市场在 now 是否可下注。
func (m Market) Open(now time.Time) bool {
	return m.Result == nil && now.Before(m.ClosesAt) && !now.Before(m.OpensAt)
}

// SettleBet：按市场结果计算单注的状态与派彩。
func SettleBet(b Bet, result string) (status string, payout int64) {
	switch {
	case result == Void:
		return BetVoid, b.Stake
	case result == b.Outcome:
		return BetWon, b.PotentialPayout
	default:
		return BetLost, 0
	}
}

// UpDownResult：收盘价相对目标价的结果。
func UpDownResult(target, close float64) string {
	switch {
	case close > target:
		return Yes
	case close < target:
		return No
	default:
		return Void
	}
}

// WindowStart：t 所在 15 分钟窗口的起点（UTC 对齐）。
func WindowStart(t time.Time) time.Time { return t.UTC().Truncate(Window) }

// UpDownID：15 分钟市场 ID，如 updown-BTC-20261120T1430Z。
func UpDownID(symbol string, start time.Time) string {
	return "updown-" + symbol + "-" + start.UTC().Format("20060102T1504Z")
}

// Stats：战绩。
type Stats struct {
	Settled   int     `json:"settled"` // 已结算（不含作废）
	Wins      int     `json:"wins"`
	HitRate   float64 `json:"hitRate"`   // 命中率（百分数，一位小数）
	NetPoints int64   `json:"netPoints"` // 累计盈亏分（已结算：派彩 − 本金）
	Claimable int64   `json:"claimable"` // 待领取积分
	OpenBets  int     `json:"openBets"`
	OpenStake int64   `json:"openStake"`
}

// ComputeStats：由下注记录计算战绩。
func ComputeStats(bets []Bet) Stats {
	var s Stats
	for _, b := range bets {
		switch b.Status {
		case BetOpen:
			s.OpenBets++
			s.OpenStake += b.Stake
			continue
		case BetVoid:
		default:
			s.Settled++
			if b.Status == BetWon {
				s.Wins++
			}
			s.NetPoints += b.Payout - b.Stake
		}
		if b.ClaimedAt == nil && b.Payout > 0 {
			s.Claimable += b.Payout
		}
	}
	if s.Settled > 0 {
		s.HitRate = math.Round(float64(s.Wins)/float64(s.Settled)*1000) / 10
	}
	return s
}
