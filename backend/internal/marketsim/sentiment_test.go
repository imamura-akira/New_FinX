package marketsim

import (
	"encoding/json"
	"math"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

func TestFearGreedLabel(t *testing.T) {
	cases := []struct {
		v    int
		want string
	}{
		{0, ExtremeFear}, {24, ExtremeFear}, {25, Fear}, {44, Fear}, {45, Neutral}, {55, Neutral},
		{56, Greed}, {62, Greed}, {75, Greed}, {76, ExtremeGreed}, {100, ExtremeGreed},
	}
	for _, c := range cases {
		if got := FearGreedLabel(c.v); got != c.want {
			t.Errorf("FearGreedLabel(%d)=%s，期望 %s", c.v, got, c.want)
		}
	}
}

func TestCountBreadth(t *testing.T) {
	cases := []struct {
		name string
		in   []float64
		want Breadth
	}{
		{"空", nil, Breadth{}},
		{"涨跌平", []float64{1.2, -0.5, 0.05, -0.09, 0.10, -0.10, 0}, Breadth{Up: 2, Down: 2, Flat: 3, Total: 7}},
		{"全涨", []float64{0.3, 2, 5}, Breadth{Up: 3, Total: 3}},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			if got := CountBreadth(c.in); got != c.want {
				t.Fatalf("得 %+v，期望 %+v", got, c.want)
			}
		})
	}
}

// 涨跌家数按全部标的的真实涨跌幅统计。
func TestSentimentBreadthMatchesQuotes(t *testing.T) {
	e, c := newTestEngine(t)
	for i := 0; i < 30; i++ {
		c.t = c.t.Add(2 * time.Second)
		e.Step()
	}
	s := e.Sentiment()
	var up, down, flat int
	for _, q := range e.Quotes(nil) {
		p := round2(q.ChgPct())
		switch {
		case math.Abs(p) < FlatThresholdPct:
			flat++
		case p > 0:
			up++
		default:
			down++
		}
	}
	if s.Breadth != (Breadth{Up: up, Down: down, Flat: flat, Total: len(DefaultInstruments)}) {
		t.Fatalf("涨跌家数 %+v，与行情统计 %d/%d/%d 不符", s.Breadth, up, down, flat)
	}
	if s.FearGreed < 0 || s.FearGreed > 100 || s.Label != FearGreedLabel(s.FearGreed) {
		t.Fatalf("指数越界或档位不符: %+v", s)
	}
}

// 指数平滑：每个 tick 变化很小（缓慢变化），且可复现。
func TestSentimentChangesSlowly(t *testing.T) {
	e, c := newTestEngine(t)
	prev := e.fearGreed
	for i := 0; i < 200; i++ {
		c.t = c.t.Add(2 * time.Second)
		e.Step()
		if d := math.Abs(e.fearGreed - prev); d > 100*sentimentAlpha {
			t.Fatalf("第 %d 步跳变 %.2f", i, d)
		}
		prev = e.fearGreed
	}
	e2, c2 := newTestEngine(t)
	for i := 0; i < 200; i++ {
		c2.t = c2.t.Add(2 * time.Second)
		e2.Step()
	}
	if e.Sentiment().FearGreed != e2.Sentiment().FearGreed {
		t.Fatal("固定种子下指数应可复现")
	}
}

func TestSentimentHTTP(t *testing.T) {
	e, _ := newTestEngine(t)
	mux := http.NewServeMux()
	e.Routes(mux, "/api/v1")
	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, httptest.NewRequest("GET", "/api/v1/market/sentiment", nil))
	if rec.Code != 200 {
		t.Fatalf("status %d", rec.Code)
	}
	var env struct {
		Code int `json:"code"`
		Data struct {
			Simulated bool      `json:"simulated"`
			Ts        time.Time `json:"ts"`
			FearGreed struct {
				Value      int        `json:"value"`
				Label      string     `json:"label"`
				Components Components `json:"components"`
			} `json:"fearGreed"`
			Breadth struct {
				Up, Down, Flat, Total int
				FlatThresholdPct      float64 `json:"flatThresholdPct"`
			} `json:"breadth"`
		} `json:"data"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &env); err != nil {
		t.Fatal(err)
	}
	d := env.Data
	if env.Code != 0 || !d.Simulated || d.Ts.IsZero() {
		t.Fatalf("响应头部不符: %s", rec.Body.String())
	}
	if d.FearGreed.Label != FearGreedLabel(d.FearGreed.Value) || d.Breadth.Total != len(DefaultInstruments) ||
		d.Breadth.Up+d.Breadth.Down+d.Breadth.Flat != d.Breadth.Total || d.Breadth.FlatThresholdPct != FlatThresholdPct {
		t.Fatalf("字段不符: %s", rec.Body.String())
	}
}
