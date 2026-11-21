// Package rewards：最小 XP 体系（F22-e Fifi 商店、F22-f 赚取 XP 任务页）。
//
//   - XP 账本（xp_ledger）：余额 = 合计，初始 0。XP 为站内成长值，与券商资金、模拟盘、预测积分完全隔离，不可兑换现金。
//   - 每日签到（xp_checkins）：每个美东日期一次（主键防重复），签到入账 +10（任务 XP 取 seed 配置）。连续天数与本周七圆点按签到记录计算。
//   - 商店商品、套装、敬请期待、等级门槛与任务均为 seed 配置（catalog.json，构建期内嵌），本期兑换未开放。
//   - 其余四项任务（学一课 / 持仓体检 / 储蓄目标 / 分享）未开放；"本月储蓄目标"为入金类任务，上线前需合规审核（上线门槛登记）。
package rewards

import (
	"context"
	_ "embed"
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"
	"sort"
	"time"

	"github.com/imamura-akira/New_FinX/backend/internal/httpx"
)

//go:embed catalog.json
var catalogJSON []byte

// Text：双语文案。
type Text struct {
	Zh string `json:"zh"`
	En string `json:"en"`
}

// Tier：等级门槛。
type Tier struct {
	Tier  int `json:"tier"`
	MinXP int `json:"minXp"`
}

// Item：商品 / 套装 / 敬请期待。
type Item struct {
	ID          string `json:"id"`
	Tier        int    `json:"tier,omitempty"` // 所在等级页签
	UnlockTier  int    `json:"unlockTier"`
	XP          int    `json:"xp,omitempty"`
	Image       string `json:"image"`                 // App 内置素材名；空 = 待配图（App 按 color 渲染纯色占位）
	Placeholder bool   `json:"placeholder,omitempty"` // 占位图，高清图后续替换
	Color       string `json:"color,omitempty"`       // 待配图时的纯色占位（#RRGGBB）
	Name        Text   `json:"name"`
	Desc        *Text  `json:"desc,omitempty"`
}

// Task：赚取 XP 任务。
type Task struct {
	ID               string `json:"id"`
	XP               int    `json:"xp"`
	Enabled          bool   `json:"enabled"`
	ComplianceReview bool   `json:"complianceReview,omitempty"` // 上线前需合规审核
}

// Catalog：seed 配置。
type Catalog struct {
	Tiers      []Tier `json:"tiers"`
	Items      []Item `json:"items"`
	Bundles    []Item `json:"bundles"`
	ComingSoon []Item `json:"comingSoon"`
	Tasks      []Task `json:"tasks"`
}

// LoadCatalog 解析内嵌 seed。
func LoadCatalog() (Catalog, error) {
	var c Catalog
	if err := json.Unmarshal(catalogJSON, &c); err != nil {
		return c, err
	}
	sort.Slice(c.Tiers, func(i, j int) bool { return c.Tiers[i].MinXP < c.Tiers[j].MinXP })
	if len(c.Tiers) == 0 || c.Tiers[0].MinXP != 0 {
		return c, errors.New("catalog: 等级门槛须从 0 XP 起")
	}
	return c, nil
}

// TierOf 返回余额所在等级与下一等级门槛（已是最高级时 next = 0）。
func (c Catalog) TierOf(balance int) (tier, nextTier, nextMin int) {
	tier = c.Tiers[0].Tier
	for i, t := range c.Tiers {
		if balance >= t.MinXP {
			tier = t.Tier
			if i+1 < len(c.Tiers) {
				nextTier, nextMin = c.Tiers[i+1].Tier, c.Tiers[i+1].MinXP
			} else {
				nextTier, nextMin = 0, 0
			}
		}
	}
	return
}

func (c Catalog) task(id string) (Task, bool) {
	for _, t := range c.Tasks {
		if t.ID == id {
			return t, true
		}
	}
	return Task{}, false
}

// Repo：持久化。
type Repo interface {
	Balance(ctx context.Context, userID string) (int, error)
	// CheckIn 记录当日签到并入账（同一天第二次返回 false，不重复入账）。
	CheckIn(ctx context.Context, userID string, day time.Time, xp int) (bool, error)
	// CheckinDays 返回 day ≥ since 的签到日期（降序）。
	CheckinDays(ctx context.Context, userID string, since time.Time) ([]time.Time, error)
}

// Service：XP 与签到。
type Service struct {
	repo    Repo
	catalog Catalog
	logger  *slog.Logger
	now     func() time.Time
	et      *time.Location
}

// New 创建模块（seed 解析失败返回错误）。
func New(repo Repo, logger *slog.Logger) (*Service, error) {
	c, err := LoadCatalog()
	if err != nil {
		return nil, err
	}
	if logger == nil {
		logger = slog.Default()
	}
	et, err := time.LoadLocation("America/New_York")
	if err != nil {
		et = time.FixedZone("ET", -5*3600)
	}
	return &Service{repo: repo, catalog: c, logger: logger, now: time.Now, et: et}, nil
}

func (s *Service) today() time.Time {
	y, m, d := s.now().In(s.et).Date()
	return time.Date(y, m, d, 0, 0, 0, 0, time.UTC)
}

// nextReset：下一个美东零点（UTC）。
func (s *Service) nextReset() time.Time {
	l := s.now().In(s.et)
	return time.Date(l.Year(), l.Month(), l.Day()+1, 0, 0, 0, 0, s.et).UTC()
}

// Routes 注册接口（均需登录）。
func (s *Service) Routes(mux *http.ServeMux, prefix string, auth func(http.Handler) http.Handler) {
	mux.Handle("GET "+prefix+"/rewards/xp", auth(http.HandlerFunc(s.handleXP)))
	mux.Handle("GET "+prefix+"/rewards/catalog", auth(http.HandlerFunc(s.handleCatalog)))
	mux.Handle("GET "+prefix+"/rewards/checkin", auth(http.HandlerFunc(s.handleCheckinStatus)))
	mux.Handle("POST "+prefix+"/rewards/checkin", auth(http.HandlerFunc(s.handleCheckin)))
}

// XPView：GET /rewards/xp。
type XPView struct {
	Balance       int `json:"balance"`
	Tier          int `json:"tier"`
	NextTier      int `json:"nextTier,omitempty"`
	NextTierMinXP int `json:"nextTierMinXp,omitempty"`
}

func (s *Service) xpView(ctx context.Context, uid string) (XPView, error) {
	b, err := s.repo.Balance(ctx, uid)
	if err != nil {
		return XPView{}, err
	}
	tier, next, nextMin := s.catalog.TierOf(b)
	return XPView{Balance: b, Tier: tier, NextTier: next, NextTierMinXP: nextMin}, nil
}

func (s *Service) handleXP(w http.ResponseWriter, r *http.Request) {
	v, err := s.xpView(r.Context(), httpx.UserID(r.Context()))
	if err != nil {
		httpx.Fail(w, r, err)
		return
	}
	httpx.OK(w, v)
}

func (s *Service) handleCatalog(w http.ResponseWriter, r *http.Request) {
	httpx.OK(w, s.catalog)
}

// CheckinView：签到状态。
type CheckinView struct {
	Today     string    `json:"today"` // 美东日期
	CheckedIn bool      `json:"checkedIn"`
	Streak    int       `json:"streak"` // 连续签到天数（今日未签时截至昨日）
	Week      [7]bool   `json:"week"`   // 本周一至周日是否已签（美东）
	ResetAt   time.Time `json:"resetAt"`
	XP        int       `json:"xp"`                // 签到奖励（seed）
	Granted   int       `json:"granted,omitempty"` // 本次入账（POST）
	Balance   int       `json:"balance"`
}

func (s *Service) status(ctx context.Context, uid string) (CheckinView, error) {
	today := s.today()
	weekday := (int(today.Weekday()) + 6) % 7 // 周一 = 0
	monday := today.AddDate(0, 0, -weekday)
	days, err := s.repo.CheckinDays(ctx, uid, today.AddDate(0, 0, -400))
	if err != nil {
		return CheckinView{}, err
	}
	set := map[time.Time]bool{}
	for _, d := range days {
		set[d] = true
	}
	v := CheckinView{Today: today.Format("2006-01-02"), CheckedIn: set[today], ResetAt: s.nextReset()}
	for i := 0; i < 7; i++ {
		v.Week[i] = set[monday.AddDate(0, 0, i)]
	}
	d := today
	if !set[d] {
		d = d.AddDate(0, 0, -1)
	}
	for set[d] {
		v.Streak++
		d = d.AddDate(0, 0, -1)
	}
	if t, ok := s.catalog.task("checkin"); ok {
		v.XP = t.XP
	}
	if v.Balance, err = s.repo.Balance(ctx, uid); err != nil {
		return CheckinView{}, err
	}
	return v, nil
}

func (s *Service) handleCheckinStatus(w http.ResponseWriter, r *http.Request) {
	v, err := s.status(r.Context(), httpx.UserID(r.Context()))
	if err != nil {
		httpx.Fail(w, r, err)
		return
	}
	httpx.OK(w, v)
}

// handleCheckin：每美东日一次；重复调用不再入账，返回当前状态（granted = 0）。
func (s *Service) handleCheckin(w http.ResponseWriter, r *http.Request) {
	ctx, uid := r.Context(), httpx.UserID(r.Context())
	t, ok := s.catalog.task("checkin")
	if !ok || !t.Enabled || t.XP <= 0 {
		httpx.Fail(w, r, httpx.NotEnabled("签到暂未开放"))
		return
	}
	inserted, err := s.repo.CheckIn(ctx, uid, s.today(), t.XP)
	if err != nil {
		httpx.Fail(w, r, err)
		return
	}
	v, err := s.status(ctx, uid)
	if err != nil {
		httpx.Fail(w, r, err)
		return
	}
	if inserted {
		v.Granted = t.XP
		s.logger.InfoContext(ctx, "xp checkin", slog.String("day", v.Today), slog.Int("xp", t.XP))
	}
	httpx.OK(w, v)
}
