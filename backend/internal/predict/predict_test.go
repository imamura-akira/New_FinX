package predict

import (
	"context"
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/imamura-akira/New_FinX/backend/internal/httpx"
)

func TestOddsAndRatio(t *testing.T) {
	if ProbYes(6800, 3200) != 0.68 || PercentYes(6800, 3200) != 68 || ProbYes(0, 0) != 0.5 {
		t.Fatal("概率")
	}
	cases := []struct {
		stake int64
		p     float64
		want  int64
	}{{100, 0.5, 200}, {100, 0.68, 147}, {100, 0.32, 312}, {100, 0.001, 5000}, {100, 0.999, 102}}
	for _, c := range cases {
		if got := Payout(c.stake, c.p); got != c.want {
			t.Errorf("Payout(%d, %.3f)=%d，期望 %d", c.stake, c.p, got, c.want)
		}
	}
}

func TestSettleRules(t *testing.T) {
	if UpDownResult(100, 101) != Yes || UpDownResult(100, 99) != No || UpDownResult(100, 100) != Void {
		t.Fatal("涨跌判定")
	}
	b := Bet{Outcome: Yes, Stake: 100, PotentialPayout: 185}
	for _, c := range []struct {
		res, st string
		pay     int64
	}{{Yes, BetWon, 185}, {No, BetLost, 0}, {Void, BetVoid, 100}} {
		if st, pay := SettleBet(b, c.res); st != c.st || pay != c.pay {
			t.Errorf("%s → %s %d", c.res, st, pay)
		}
	}
	start := WindowStart(time.Date(2026, 11, 20, 14, 37, 12, 0, time.UTC))
	if !start.Equal(time.Date(2026, 11, 20, 14, 30, 0, 0, time.UTC)) || UpDownID("BTC", start) != "updown-BTC-20261120T1430Z" {
		t.Fatal("窗口")
	}
}

func TestStats(t *testing.T) {
	now := time.Now()
	s := ComputeStats([]Bet{
		{Status: BetOpen, Stake: 50},
		{Status: BetWon, Stake: 100, Payout: 200},
		{Status: BetWon, Stake: 100, Payout: 150, ClaimedAt: &now},
		{Status: BetLost, Stake: 100},
		{Status: BetVoid, Stake: 80, Payout: 80},
	})
	if s.OpenBets != 1 || s.OpenStake != 50 || s.Settled != 3 || s.Wins != 2 || s.HitRate != 66.7 || s.NetPoints != 50 || s.Claimable != 280 {
		t.Fatalf("%+v", s)
	}
}

// ---------- 服务 ----------

type fx struct {
	svc   *Service
	repo  *Mem
	now   time.Time
	price map[string]float64
	mux   *http.ServeMux
}

func event(id string, yes, no int64, closes time.Time) Market {
	return Market{ID: id, Kind: KindEvent, Category: "MACRO", TitleZh: "问题", TitleEn: "Question", YesZh: "会", YesEn: "Yes", NoZh: "不会", NoEn: "No",
		SeedYes: yes, SeedNo: no, PoolYes: yes, PoolNo: no, OpensAt: time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC), ClosesAt: closes}
}

func newFx(t *testing.T) *fx {
	t.Helper()
	f := &fx{now: time.Date(2026, 11, 20, 14, 31, 0, 0, time.UTC), price: map[string]float64{"BTC": 61500, "SOL": 145}}
	f.repo = NewMem(event("fed", 6800, 3200, time.Date(2026, 12, 18, 0, 0, 0, 0, time.UTC)), event("old", 50, 50, time.Date(2026, 11, 1, 0, 0, 0, 0, time.UTC)))
	f.svc = New(Deps{Repo: f.repo, Price: func(s string) (float64, bool) { p, ok := f.price[s]; return p, ok }, Logger: slog.New(slog.NewTextHandler(io.Discard, nil))})
	f.svc.now = func() time.Time { return f.now }
	f.mux = http.NewServeMux()
	f.svc.Routes(f.mux, "/api/v1", func(h http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			h.ServeHTTP(w, r.WithContext(httpx.WithUser(r.Context(), "u1")))
		})
	})
	return f
}

func (f *fx) call(method, path, body string) (int, map[string]any) {
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(method, path, strings.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	f.mux.ServeHTTP(rec, req)
	var env map[string]any
	_ = json.Unmarshal(rec.Body.Bytes(), &env)
	return int(env["code"].(float64)), env
}

func data(env map[string]any) map[string]any { return env["data"].(map[string]any) }

func TestMarketsAndWindows(t *testing.T) {
	f := newFx(t)
	code, env := f.call("GET", "/api/v1/predict/markets", "")
	if code != 0 {
		t.Fatalf("code %d", code)
	}
	d := data(env)
	ud, ev := d["updown"].([]any), d["events"].([]any)
	if len(ud) != 2 || len(ev) != 1 {
		t.Fatalf("应有 BTC / SOL 两个 15 分钟市场与 1 个未截止事件，得 %d / %d", len(ud), len(ev))
	}
	btc := ud[0].(map[string]any)
	if btc["id"] != "updown-BTC-20261120T1430Z" || btc["targetPrice"].(float64) != 61500 || btc["closesAt"] != "2026-11-20T14:45:00Z" {
		t.Fatalf("BTC 窗口 %v", btc)
	}
	if o := ev[0].(map[string]any)["outcomes"].([]any); o[0].(map[string]any)["percent"].(float64) != 68 || o[1].(map[string]any)["percent"].(float64) != 32 {
		t.Fatalf("概率 %v", o)
	}
	// 分类筛选
	_, env = f.call("GET", "/api/v1/predict/markets?category=CRYPTO", "")
	if len(data(env)["events"].([]any)) != 0 || len(data(env)["updown"].([]any)) != 2 {
		t.Fatal("分类筛选")
	}
}

// 下注扣分、赔率按下注时比例、比例随下注变化。
func TestBetDeductsAndMovesRatio(t *testing.T) {
	f := newFx(t)
	code, env := f.call("POST", "/api/v1/predict/bets", `{"marketId":"fed","outcome":"NO","stake":1000}`)
	if code != 0 {
		t.Fatalf("下注失败 %v", env)
	}
	d := data(env)
	bet := d["bet"].(map[string]any)
	if d["points"].(float64) != 9000 || bet["potentialPayout"].(float64) != 3125 || bet["probability"].(float64) != 0.32 {
		t.Fatalf("扣分 / 赔率 %v", d)
	}
	// NO 池 3200 + 1000 → YES 6800 / 11000 = 61.8% → 62
	if o := d["market"].(map[string]any)["outcomes"].([]any); o[0].(map[string]any)["percent"].(float64) != 62 {
		t.Fatalf("比例应随下注变化 %v", o)
	}
	_, env = f.call("GET", "/api/v1/predict/account", "")
	if data(env)["points"].(float64) != 9000 || data(env)["stats"].(map[string]any)["openBets"].(float64) != 1 {
		t.Fatalf("账户 %v", data(env))
	}
}

func TestBetValidation(t *testing.T) {
	f := newFx(t)
	for _, c := range []struct {
		body string
		code int
	}{
		{`{"marketId":"fed","outcome":"YES","stake":5}`, httpx.CodeValidation},
		{`{"marketId":"fed","outcome":"YES","stake":5001}`, httpx.CodeValidation},
		{`{"marketId":"fed","outcome":"MAYBE","stake":100}`, httpx.CodeValidation},
		{`{"marketId":"fed","outcome":"YES","stake":"abc"}`, httpx.CodeValidation},
		{`{"marketId":"old","outcome":"YES","stake":100}`, httpx.CodeConflict},
		{`{"marketId":"nope","outcome":"YES","stake":100}`, httpx.CodeConflict},
	} {
		if code, _ := f.call("POST", "/api/v1/predict/bets", c.body); code != c.code {
			t.Errorf("%s → %d，期望 %d", c.body, code, c.code)
		}
	}
	// 积分不足
	for i := 0; i < 2; i++ {
		f.call("POST", "/api/v1/predict/bets", `{"marketId":"fed","outcome":"YES","stake":5000}`)
	}
	if code, _ := f.call("POST", "/api/v1/predict/bets", `{"marketId":"fed","outcome":"YES","stake":10}`); code != httpx.CodeLimit {
		t.Fatalf("积分不足应 42201，得 %d", code)
	}
}

// 15 分钟市场到期按虚拟行情自动结算；命中者领取派彩，未命中为 0；下一个窗口自动创建。
func TestUpDownAutoSettleAndClaim(t *testing.T) {
	f := newFx(t)
	ctx := context.Background()
	f.svc.EnsureWindows(ctx)
	f.call("POST", "/api/v1/predict/bets", `{"marketId":"updown-BTC-20261120T1430Z","outcome":"YES","stake":100}`)
	f.call("POST", "/api/v1/predict/bets", `{"marketId":"updown-SOL-20261120T1430Z","outcome":"YES","stake":100}`)
	f.now = time.Date(2026, 11, 20, 14, 45, 3, 0, time.UTC)
	f.price["BTC"], f.price["SOL"] = 61600, 144
	f.svc.SettleDue(ctx)
	f.svc.EnsureWindows(ctx)
	_, env := f.call("GET", "/api/v1/predict/bets", "")
	stats := data(env)["stats"].(map[string]any)
	if stats["wins"].(float64) != 1 || stats["settled"].(float64) != 2 || stats["claimable"].(float64) != 200 || stats["hitRate"].(float64) != 50 {
		t.Fatalf("结算战绩 %v", stats)
	}
	_, env = f.call("POST", "/api/v1/predict/claim", "")
	if data(env)["claimed"].(float64) != 200 || data(env)["points"].(float64) != 10000 {
		t.Fatalf("领取 %v", data(env))
	}
	if _, env = f.call("POST", "/api/v1/predict/claim", ""); data(env)["claimed"].(float64) != 0 {
		t.Fatal("不应重复领取")
	}
	_, env = f.call("GET", "/api/v1/predict/markets", "")
	if data(env)["updown"].([]any)[0].(map[string]any)["id"] != "updown-BTC-20261120T1445Z" {
		t.Fatal("应创建下一个窗口")
	}
}

// 结算过迟（服务停机）作废退回本金；事件市场人工结算 VOID 也退回。
func TestLateVoidAndEventSettle(t *testing.T) {
	f := newFx(t)
	ctx := context.Background()
	f.svc.EnsureWindows(ctx)
	f.call("POST", "/api/v1/predict/bets", `{"marketId":"updown-BTC-20261120T1430Z","outcome":"NO","stake":200}`)
	f.call("POST", "/api/v1/predict/bets", `{"marketId":"fed","outcome":"YES","stake":100}`)
	f.now = time.Date(2026, 11, 20, 15, 30, 0, 0, time.UTC)
	f.svc.SettleDue(ctx)
	if _, err := f.repo.Settle(ctx, "fed", Yes, nil, f.now); err != nil {
		t.Fatal(err)
	}
	if _, err := f.repo.Settle(ctx, "fed", No, nil, f.now); err != ErrSettled {
		t.Fatal("不可重复结算")
	}
	_, env := f.call("POST", "/api/v1/predict/claim", "")
	// 作废退 200；fed YES 命中 floor(100 / 0.68) = 147
	if data(env)["claimed"].(float64) != 347 {
		t.Fatalf("领取 %v", data(env))
	}
}
