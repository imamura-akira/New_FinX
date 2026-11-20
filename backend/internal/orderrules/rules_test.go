package orderrules

import (
	"encoding/json"
	"testing"
)

func TestParseLimitPrice(t *testing.T) {
	ok := map[string]float64{"195": 195, "195.5": 195.5, "0.1234": 0.1234, "1.25": 1.25, "0.5": 0.5}
	for in, want := range ok {
		if got, err := ParseLimitPrice(json.RawMessage(in)); err != nil || got != want {
			t.Errorf("%s → %v %v", in, got, err)
		}
	}
	for _, in := range []string{"0", "0.0", "-1", `"10"`, "null", "", "1.234", "0.12345", "1e3"} {
		if _, err := ParseLimitPrice(json.RawMessage(in)); err == nil {
			t.Errorf("%q 应被拒绝", in)
		}
	}
}
