// Package marketstats：P-09 市场统计（F22-b）——标的池全部股票与 ETF 的涨跌分布。
//
//   - 今日：按虚拟行情当前涨跌幅（相对昨收）实时统计。
//   - 近 30 日：每个标的"当前价相对 30 个自然日前（含）最近一个收盘快照"的涨跌幅。收盘快照由本模块在美东交易日收盘后
//     （16:05 起）写入 instrument_daily_close；任一标的没有 30 天前的快照时返回 insufficient=true（App 显示"数据积累中"），不补造历史。
//
// 分布 9 档（与定稿 market_v2 一致，单位 %）：≤-7、(-7,-5]、(-5,-3]、(-3,0)、平、(0,3)、[3,5)、[5,7)、≥7；
// |涨跌幅| < FlatPct 记为平。全部为演示用虚拟行情统计。
package marketstats

import (
	"context"
	"log/slog"
	"math"
	"net/http"
	"strings"
	"time"

	"github.com/imamura-akira/New_FinX/backend/internal/httpx"
)

// FlatPct：|涨跌幅| 小于该值（%）记为平（两位小数显示为 0.00%）。
const FlatPct = 0.005

// Window：近 N 日的自然日数。
const Window = 30

// CloseAfter：美东收盘快照起始时刻（16:00 收盘后留 5 分钟）。
const CloseAfter = 16*time.Hour + 5*time.Minute

// Labels：分布档位（从大跌到大涨）。
var Labels = [9]string{">7%", "7~5", "5~3", "3~0", "0", "0~3", "3~5", "5~7", ">7%"}

// Bucket 返回涨跌幅（%）所在档位序号 0–8。
func Bucket(chg float64) int {
	switch {
	case math.Abs(chg) < FlatPct:
		return 4
	case chg <= -7:
		return 0
	case chg <= -5:
		return 1
	case chg <= -3:
		return 2
	case chg < 0:
		return 3
	case chg < 3:
		return 5
	case chg < 5:
		return 6
	case chg < 7:
		return 7
	}
	return 8
}

// Distribution：分布结果。
type Distribution struct {
	Counts         [9]int
	Up, Down, Flat int
	Total          int
}

// Distribute 统计一组涨跌幅（%）。
func Distribute(chgs []float64) Distribution {
	var d Distribution
	for _, c := range chgs {
		b := Bucket(c)
		d.Counts[b]++
		switch {
		case b < 4:
			d.Down++
		case b > 4:
			d.Up++
		default:
			d.Flat++
		}
	}
	d.Total = len(chgs)
	return d
}

// Quote：统计用报价（标的池中的股票与 ETF）。
type Quote struct {
	Symbol string
	Last   float64
	ChgPct float64 // 相对昨收，%
}

// Close：某日收盘快照。
type Close struct {
	Symbol string
	Day    time.Time // 美东日期（00:00 UTC 表示）
	Close  float64
	ChgPct float64
}

// Repo：收盘快照持久化。
type Repo interface {
	SaveCloses(ctx context.Context, cs []Close) error
	// BaseCloses 返回每个代码 day ≤ onOrBefore 的最近一个收盘价。
	BaseCloses(ctx context.Context, onOrBefore time.Time) (map[string]float64, error)
	// FirstDay 返回最早的快照日期（无快照时 ok=false）。
	FirstDay(ctx context.Context) (time.Time, bool, error)
}

// Deps：依赖。Quotes 返回当前全部股票与 ETF 报价。
type Deps struct {
	Repo   Repo
	Quotes func() []Quote
	Logger *slog.Logger
}

// Service：市场统计。
type Service struct {
	Deps
	now  func() time.Time
	et   *time.Location
	last time.Time // 最近完成收盘快照的美东日期
}

// New 创建模块。
func New(d Deps) *Service {
	if d.Logger == nil {
		d.Logger = slog.Default()
	}
	et, err := time.LoadLocation("America/New_York")
	if err != nil {
		et = time.FixedZone("ET", -5*3600)
	}
	return &Service{Deps: d, now: time.Now, et: et}
}

func dayOf(t time.Time, loc *time.Location) time.Time {
	y, m, d := t.In(loc).Date()
	return time.Date(y, m, d, 0, 0, 0, 0, time.UTC)
}

// Run 周期检查收盘快照，直到 ctx 结束。
func (s *Service) Run(ctx context.Context, every time.Duration) {
	t := time.NewTicker(every)
	defer t.Stop()
	for {
		s.Tick(ctx)
		select {
		case <-ctx.Done():
			return
		case <-t.C:
		}
	}
}

// Tick：美东周一至周五 16:05 之后、当日尚未记录时，为全部股票与 ETF 写收盘快照。
func (s *Service) Tick(ctx context.Context) {
	now := s.now().In(s.et)
	if now.Weekday() == time.Saturday || now.Weekday() == time.Sunday {
		return
	}
	today := dayOf(now, s.et)
	midnight := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, s.et)
	if now.Sub(midnight) < CloseAfter || s.last.Equal(today) {
		return
	}
	qs := s.Quotes()
	cs := make([]Close, 0, len(qs))
	for _, q := range qs {
		cs = append(cs, Close{Symbol: q.Symbol, Day: today, Close: q.Last, ChgPct: q.ChgPct})
	}
	if err := s.Repo.SaveCloses(ctx, cs); err != nil {
		s.Logger.WarnContext(ctx, "daily close snapshot failed", slog.String("error", err.Error()))
		return
	}
	s.last = today
	s.Logger.InfoContext(ctx, "daily close snapshot recorded", slog.String("day", today.Format("2006-01-02")), slog.Int("symbols", len(cs)))
}

// Routes 注册 GET /market/stats（与其他 /market/* 一致，不要求登录：虚拟行情统计，不含用户信息）。
func (s *Service) Routes(mux *http.ServeMux, prefix string) {
	mux.HandleFunc("GET "+prefix+"/market/stats", s.handle)
}

type bucketView struct {
	Label string `json:"label"`
	Count int    `json:"count"`
}

// View：GET /market/stats 的数据。
type View struct {
	Simulated    bool         `json:"simulated"`
	Period       string       `json:"period"` // TODAY / 30D
	Insufficient bool         `json:"insufficient"`
	Since        string       `json:"since,omitempty"` // 最早收盘快照日期（30D）
	Buckets      []bucketView `json:"buckets"`
	Up           int          `json:"up"`
	Down         int          `json:"down"`
	Flat         int          `json:"flat"`
	Total        int          `json:"total"`
	AsOf         time.Time    `json:"asOf"`
}

func view(period string, d Distribution, now time.Time) View {
	v := View{Simulated: true, Period: period, Up: d.Up, Down: d.Down, Flat: d.Flat, Total: d.Total, AsOf: now.UTC()}
	for i, l := range Labels {
		v.Buckets = append(v.Buckets, bucketView{Label: l, Count: d.Counts[i]})
	}
	return v
}

func (s *Service) handle(w http.ResponseWriter, r *http.Request) {
	period := strings.ToUpper(strings.TrimSpace(r.URL.Query().Get("period")))
	if period == "" {
		period = "TODAY"
	}
	now := s.now()
	qs := s.Quotes()
	switch period {
	case "TODAY":
		chgs := make([]float64, 0, len(qs))
		for _, q := range qs {
			chgs = append(chgs, q.ChgPct)
		}
		httpx.OK(w, view(period, Distribute(chgs), now))
	case "30D":
		ctx := r.Context()
		base, err := s.Repo.BaseCloses(ctx, dayOf(now, s.et).AddDate(0, 0, -Window))
		if err != nil {
			httpx.Fail(w, r, err)
			return
		}
		chgs := make([]float64, 0, len(qs))
		missing := false
		for _, q := range qs {
			b, ok := base[q.Symbol]
			if !ok || b <= 0 {
				missing = true
				break
			}
			chgs = append(chgs, (q.Last-b)/b*100)
		}
		if missing || len(qs) == 0 {
			v := view(period, Distribution{}, now)
			v.Insufficient = true
			if first, ok, err := s.Repo.FirstDay(ctx); err == nil && ok {
				v.Since = first.Format("2006-01-02")
			}
			httpx.OK(w, v)
			return
		}
		httpx.OK(w, view(period, Distribute(chgs), now))
	default:
		httpx.Fail(w, r, httpx.Validation("", httpx.FieldError{Field: "period", Reason: "period 只支持 TODAY、30D"}))
	}
}
