// Package portfolio：资产分布与资产趋势（F17，api-spec.md 3.x GET /account/allocation、/account/history 及模拟盘对应接口）。
//
//   - 分布：实盘现金取 DW summary/money 的 cash.cashBalance（与 GET /account/money 的 cash 同源），持仓市值取 DW
//     summary/positions 的 marketValue，按我方标的列表的 STOCK / ETF 分类归堆（列表外的代码按股票计）；
//     模拟盘取模拟账户现金与持仓（按虚拟行情估值）。占比由后端计算（一位小数，最大余数法保证合计 100.0）。
//   - 趋势：每日资产快照（asset_snapshots），每个用户 × 账户类型 × 美东日期一条。收盘后（美东 16:10 起）任务为每个
//     已开户用户与每个模拟账户记录 CLOSE 快照；当日首次请求分布 / 趋势时若尚无记录，兜底写入 FIRST_REQUEST 快照，
//     之后的 CLOSE 快照覆盖它。快照为内部记录，金额一律来自 DW / 模拟账户返回，不自行推算历史。
//   - 日内（F22-a，1D）：美东交易日盘中 09:30–16:00 每 30 分钟一档，为全部实盘 / 模拟盘用户记录日内快照（asset_intraday）。
//     1D 返回最近一个有日内快照的美东日期的各档（不足 2 点时 App 显示"日内数据积累中"）。
package portfolio

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"sort"
	"strconv"
	"strings"
	"time"

	"github.com/imamura-akira/New_FinX/backend/internal/httpx"
)

// Mode：账户类型。
type Mode string

const (
	Real  Mode = "REAL"
	Paper Mode = "PAPER"
)

// 快照来源。
const (
	SourceClose        = "CLOSE"
	SourceFirstRequest = "FIRST_REQUEST"
)

// 资产类别（分布条目顺序：股票、ETF、现金，与 P-07 定稿一致）。
const (
	TypeStock = "STOCK"
	TypeETF   = "ETF"
	TypeCash  = "CASH"
)

// ErrNotOpened：实盘账户尚未开立。
var ErrNotOpened = errors.New("account not opened")

// Breakdown：资产构成（单位：分）。
type Breakdown struct {
	Cash, Stock, ETF int64
}

// Total：总资产 = 现金 + 股票市值 + ETF 市值（各项均为 DW / 模拟账户返回值）。
func (b Breakdown) Total() int64 { return b.Cash + b.Stock + b.ETF }

// Holding：单个持仓的市值（分）。
type Holding struct {
	Symbol string
	Value  int64
}

// Group 按 classify 把持仓市值归入股票 / ETF；classify 返回 ETF 以外的值一律按股票计。
func Group(cash int64, holdings []Holding, classify func(string) string) Breakdown {
	b := Breakdown{Cash: cash}
	for _, h := range holdings {
		if classify != nil && classify(strings.ToUpper(h.Symbol)) == TypeETF {
			b.ETF += h.Value
		} else {
			b.Stock += h.Value
		}
	}
	return b
}

// Item：分布条目。
type Item struct {
	Type   string      `json:"type"`
	Amount json.Number `json:"amount"`
	Pct    json.Number `json:"pct"` // 百分数，一位小数，如 45.0
}

// Percents 计算股票 / ETF / 现金占比（千分位整数，合计 1000；负数按 0 计；总额为 0 时全为 0）。
// 先按比例取整，再把余下的千分位按余数从大到小分配（最大余数法）。
func Percents(b Breakdown) [3]int {
	vals := [3]int64{max(b.Stock, 0), max(b.ETF, 0), max(b.Cash, 0)}
	sum := vals[0] + vals[1] + vals[2]
	var out [3]int
	if sum <= 0 {
		return out
	}
	type rem struct {
		i int
		r int64
	}
	rems := make([]rem, 3)
	given := 0
	for i, v := range vals {
		out[i] = int(v * 1000 / sum)
		given += out[i]
		rems[i] = rem{i, v * 1000 % sum}
	}
	sort.SliceStable(rems, func(a, c int) bool { return rems[a].r > rems[c].r })
	for k := 0; given < 1000; k++ {
		if vals[rems[k%3].i] > 0 {
			out[rems[k%3].i]++
			given++
		}
	}
	return out
}

// Allocate 返回分布条目（股票、ETF、现金）。
func Allocate(b Breakdown) []Item {
	p := Percents(b)
	return []Item{
		{TypeStock, Cents(b.Stock), pct(p[0])},
		{TypeETF, Cents(b.ETF), pct(p[1])},
		{TypeCash, Cents(b.Cash), pct(p[2])},
	}
}

func pct(permille int) json.Number {
	return json.Number(strconv.Itoa(permille/10) + "." + strconv.Itoa(permille%10))
}

// Cents：分 → 两位小数的 JSON number。
func Cents(c int64) json.Number {
	neg := ""
	if c < 0 {
		neg, c = "-", -c
	}
	return json.Number(fmt.Sprintf("%s%d.%02d", neg, c/100, c%100))
}

// Snapshot：每日资产快照。
type Snapshot struct {
	UserID     string
	Mode       Mode
	Day        time.Time // 美东日期（00:00 UTC 表示）
	Breakdown  Breakdown
	Source     string
	CapturedAt time.Time
}

// Repo：快照持久化。
type Repo interface {
	// Save 写入快照：overwrite=true（CLOSE）覆盖当日已有记录；false（FIRST_REQUEST）仅在当日无记录时写入。返回是否写入。
	Save(ctx context.Context, s Snapshot, overwrite bool) (bool, error)
	Has(ctx context.Context, userID string, mode Mode, day time.Time) (bool, error)
	// List 返回 day ≥ from 的快照（from 为零值时返回全部），按日期升序。
	List(ctx context.Context, userID string, mode Mode, from time.Time) ([]Snapshot, error)
	RealUsers(ctx context.Context) ([]string, error)
	PaperUsers(ctx context.Context) ([]string, error)
	// SaveIntraday 写入日内快照（同一档位已存在时忽略）；ListIntraday 返回 At ≥ since 的日内快照，按时刻升序。
	SaveIntraday(ctx context.Context, s IntradaySnapshot) error
	ListIntraday(ctx context.Context, userID string, mode Mode, since time.Time) ([]IntradaySnapshot, error)
}

// IntradaySnapshot：日内资产快照（F22-a）。At 为档位时刻（美东 09:30 起每 30 分钟，UTC 存储）。
type IntradaySnapshot struct {
	UserID     string
	Mode       Mode
	At         time.Time
	Breakdown  Breakdown
	CapturedAt time.Time
}

// Source：读取用户当前资产构成。
type Source func(ctx context.Context, userID string) (Breakdown, error)

// Deps：外部依赖。Real / Paper 为 nil 时不挂载对应接口、也不记录对应快照。
type Deps struct {
	Repo   Repo
	Real   Source
	Paper  Source
	Logger *slog.Logger
}

// CloseAfter：美东时间每日收盘快照的起始时刻（16:00 收盘后留 10 分钟让 DW 估值更新）。
const CloseAfter = 16*time.Hour + 10*time.Minute

// Service：资产分布与趋势。
type Service struct {
	Deps
	now       func() time.Time
	et        *time.Location
	lastClose map[Mode]time.Time
	lastSlot  map[Mode]time.Time
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
	return &Service{Deps: d, now: time.Now, et: et, lastClose: map[Mode]time.Time{}, lastSlot: map[Mode]time.Time{}}
}

// Today：当前美东日期。
func (s *Service) Today() time.Time { return dayOf(s.now(), s.et) }

func dayOf(t time.Time, loc *time.Location) time.Time {
	y, m, d := t.In(loc).Date()
	return time.Date(y, m, d, 0, 0, 0, 0, time.UTC)
}

// Routes 注册接口。
func (s *Service) Routes(mux *http.ServeMux, prefix string, auth func(http.Handler) http.Handler) {
	h := func(f http.HandlerFunc) http.Handler { return auth(f) }
	if s.Real != nil {
		mux.Handle("GET "+prefix+"/account/allocation", h(s.allocation(Real)))
		mux.Handle("GET "+prefix+"/account/history", h(s.history(Real)))
	}
	if s.Paper != nil {
		mux.Handle("GET "+prefix+"/paper/account/allocation", h(s.allocation(Paper)))
		mux.Handle("GET "+prefix+"/paper/account/history", h(s.history(Paper)))
	}
}

func (s *Service) source(m Mode) Source {
	if m == Paper {
		return s.Paper
	}
	return s.Real
}

func (s *Service) fail(ctx context.Context, m Mode, err error) error {
	var he *httpx.Error
	switch {
	case errors.Is(err, ErrNotOpened):
		return httpx.Conflict("交易账户尚未开立")
	case errors.As(err, &he):
		return he
	}
	s.Logger.WarnContext(ctx, "portfolio source failed", slog.String("mode", string(m)), slog.String("error", err.Error()))
	if m == Real {
		return httpx.DWFailed()
	}
	return httpx.Internal()
}

// record 写当日兜底快照（失败只记日志，不影响接口）。
func (s *Service) record(ctx context.Context, userID string, m Mode, b Breakdown) {
	_, err := s.Repo.Save(ctx, Snapshot{UserID: userID, Mode: m, Day: s.Today(), Breakdown: b, Source: SourceFirstRequest, CapturedAt: s.now().UTC()}, false)
	if err != nil {
		s.Logger.WarnContext(ctx, "snapshot save failed", slog.String("mode", string(m)), slog.String("error", err.Error()))
	}
}

// AllocationView：GET /account/allocation 的数据。
type AllocationView struct {
	Simulated bool        `json:"simulated"`
	Total     json.Number `json:"total"`
	Items     []Item      `json:"items"`
	UpdatedAt time.Time   `json:"updatedAt"`
}

func (s *Service) allocation(m Mode) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx, uid := r.Context(), httpx.UserID(r.Context())
		b, err := s.source(m)(ctx, uid)
		if err != nil {
			httpx.Fail(w, r, s.fail(ctx, m, err))
			return
		}
		s.record(ctx, uid, m, b)
		httpx.OK(w, AllocationView{Simulated: m == Paper, Total: Cents(b.Total()), Items: Allocate(b), UpdatedAt: s.now().UTC()})
	}
}

// Point：趋势点。
type Point struct {
	Date  string      `json:"date"`         // 美东日期 YYYY-MM-DD
	At    string      `json:"at,omitempty"` // 1D 日内档位时刻（RFC 3339，UTC）；按日的区间不返回
	Total json.Number `json:"total"`
	Cash  json.Number `json:"cash"`
	Stock json.Number `json:"stock"`
	ETF   json.Number `json:"etf"`
}

// HistoryView：GET /account/history 的数据。
type HistoryView struct {
	Simulated bool    `json:"simulated"`
	Range     string  `json:"range"`
	Points    []Point `json:"points"`
}

// RangeDays：7D / 30D / 90D 为含今日的最近 N 个美东自然日；ALL 为全部（0）。
// F22-a 新增：1W = 7、3M = 90、1Y = 365 个自然日；YTD 与 1D 不按天数计（见 history），此处返回 0。
func RangeDays(r string) (int, bool) {
	switch strings.ToUpper(strings.TrimSpace(r)) {
	case "", "7D", "1W":
		return 7, true
	case "30D":
		return 30, true
	case "90D", "3M":
		return 90, true
	case "1Y":
		return 365, true
	case "ALL", "YTD", "1D":
		return 0, true
	}
	return 0, false
}

// IntradaySlot：t 所在的日内档位（美东周一至周五 09:30–16:00，每 30 分钟一档，含 16:00 收盘档）；盘外返回 false。
func IntradaySlot(t time.Time, et *time.Location) (time.Time, bool) {
	l := t.In(et)
	if l.Weekday() == time.Saturday || l.Weekday() == time.Sunday {
		return time.Time{}, false
	}
	mins := l.Hour()*60 + l.Minute()
	if mins < 9*60+30 || mins > 16*60 {
		return time.Time{}, false
	}
	slot := mins - mins%30
	return time.Date(l.Year(), l.Month(), l.Day(), slot/60, slot%60, 0, 0, et).UTC(), true
}

// intraday：最近一个有日内快照的美东日期（7 天内）的全部档位。
func (s *Service) intraday(ctx context.Context, uid string, m Mode) ([]Point, error) {
	snaps, err := s.Repo.ListIntraday(ctx, uid, m, s.now().Add(-7*24*time.Hour))
	if err != nil || len(snaps) == 0 {
		return []Point{}, err
	}
	last := dayOf(snaps[len(snaps)-1].At, s.et)
	pts := []Point{}
	for _, sn := range snaps {
		if !dayOf(sn.At, s.et).Equal(last) {
			continue
		}
		b := sn.Breakdown
		pts = append(pts, Point{Date: last.Format("2006-01-02"), At: sn.At.UTC().Format(time.RFC3339), Total: Cents(b.Total()), Cash: Cents(b.Cash), Stock: Cents(b.Stock), ETF: Cents(b.ETF)})
	}
	return pts, nil
}

func (s *Service) history(m Mode) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx, uid := r.Context(), httpx.UserID(r.Context())
		raw := r.URL.Query().Get("range")
		days, ok := RangeDays(raw)
		if !ok {
			httpx.Fail(w, r, httpx.Validation("", httpx.FieldError{Field: "range", Reason: "range 只支持 1D、1W、3M、1Y、YTD、7D、30D、90D、ALL"}))
			return
		}
		rng := strings.ToUpper(strings.TrimSpace(raw))
		if rng == "" {
			rng = "7D"
		}
		today := s.Today()
		// 当日兜底：今日尚无快照时读取一次当前资产并记录（未开户等错误照常返回）
		has, err := s.Repo.Has(ctx, uid, m, today)
		if err != nil {
			httpx.Fail(w, r, err)
			return
		}
		if !has {
			b, err := s.source(m)(ctx, uid)
			if err != nil {
				httpx.Fail(w, r, s.fail(ctx, m, err))
				return
			}
			s.record(ctx, uid, m, b)
		}
		if rng == "1D" {
			pts, err := s.intraday(ctx, uid, m)
			if err != nil {
				httpx.Fail(w, r, err)
				return
			}
			httpx.OK(w, HistoryView{Simulated: m == Paper, Range: rng, Points: pts})
			return
		}
		var from time.Time
		if days > 0 {
			from = today.AddDate(0, 0, -(days - 1))
		} else if rng == "YTD" {
			from = time.Date(today.Year(), 1, 1, 0, 0, 0, 0, time.UTC)
		}
		snaps, err := s.Repo.List(ctx, uid, m, from)
		if err != nil {
			httpx.Fail(w, r, err)
			return
		}
		pts := make([]Point, 0, len(snaps))
		for _, sn := range snaps {
			b := sn.Breakdown
			pts = append(pts, Point{Date: sn.Day.Format("2006-01-02"), Total: Cents(b.Total()), Cash: Cents(b.Cash), Stock: Cents(b.Stock), ETF: Cents(b.ETF)})
		}
		httpx.OK(w, HistoryView{Simulated: m == Paper, Range: rng, Points: pts})
	}
}

// ---------- 每日收盘快照 ----------

// Run 周期检查：美东 16:10 之后、当日尚未完成时，为全部用户记录 CLOSE 快照。
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

// Tick 执行一次检查（导出供测试）：盘中按档位记录日内快照；收盘后记录当日 CLOSE 快照。
func (s *Service) Tick(ctx context.Context) {
	now := s.now().In(s.et)
	today := dayOf(now, s.et)
	if slot, ok := IntradaySlot(now, s.et); ok {
		for _, m := range []Mode{Real, Paper} {
			if s.source(m) == nil || s.lastSlot[m].Equal(slot) {
				continue
			}
			if s.IntradayAll(ctx, m, slot) {
				s.lastSlot[m] = slot
			}
		}
	}
	if now.Sub(time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, s.et)) < CloseAfter {
		return
	}
	for _, m := range []Mode{Real, Paper} {
		src := s.source(m)
		if src == nil || s.lastClose[m].Equal(today) {
			continue
		}
		if s.SnapshotAll(ctx, m, today) {
			s.lastClose[m] = today
		}
	}
}

// SnapshotAll 为某类账户的全部用户记录 CLOSE 快照；全部成功返回 true（部分失败下一轮重试，已写入的覆盖为同值）。
func (s *Service) SnapshotAll(ctx context.Context, m Mode, day time.Time) bool {
	list := s.Repo.RealUsers
	if m == Paper {
		list = s.Repo.PaperUsers
	}
	users, err := list(ctx)
	if err != nil {
		s.Logger.WarnContext(ctx, "snapshot users query failed", slog.String("mode", string(m)), slog.String("error", err.Error()))
		return false
	}
	ok, n := true, 0
	for _, uid := range users {
		b, err := s.source(m)(ctx, uid)
		if err != nil {
			if !errors.Is(err, ErrNotOpened) {
				ok = false
				s.Logger.WarnContext(ctx, "close snapshot source failed", slog.String("mode", string(m)), slog.String("error", err.Error()))
			}
			continue
		}
		if _, err := s.Repo.Save(ctx, Snapshot{UserID: uid, Mode: m, Day: day, Breakdown: b, Source: SourceClose, CapturedAt: s.now().UTC()}, true); err != nil {
			ok = false
			s.Logger.WarnContext(ctx, "close snapshot save failed", slog.String("mode", string(m)), slog.String("error", err.Error()))
			continue
		}
		n++
	}
	s.Logger.InfoContext(ctx, "close snapshots recorded", slog.String("mode", string(m)), slog.String("day", day.Format("2006-01-02")), slog.Int("users", n))
	return ok
}

// IntradayAll 为某类账户的全部用户记录一档日内快照；全部成功返回 true（部分失败下一轮重试，已写入的忽略）。
func (s *Service) IntradayAll(ctx context.Context, m Mode, slot time.Time) bool {
	list := s.Repo.RealUsers
	if m == Paper {
		list = s.Repo.PaperUsers
	}
	users, err := list(ctx)
	if err != nil {
		s.Logger.WarnContext(ctx, "intraday users query failed", slog.String("mode", string(m)), slog.String("error", err.Error()))
		return false
	}
	ok := true
	for _, uid := range users {
		b, err := s.source(m)(ctx, uid)
		if err != nil {
			if !errors.Is(err, ErrNotOpened) {
				ok = false
				s.Logger.WarnContext(ctx, "intraday source failed", slog.String("mode", string(m)), slog.String("error", err.Error()))
			}
			continue
		}
		if err := s.Repo.SaveIntraday(ctx, IntradaySnapshot{UserID: uid, Mode: m, At: slot, Breakdown: b, CapturedAt: s.now().UTC()}); err != nil {
			ok = false
			s.Logger.WarnContext(ctx, "intraday save failed", slog.String("mode", string(m)), slog.String("error", err.Error()))
		}
	}
	return ok
}
