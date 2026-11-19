package application

import (
	"strings"
	"testing"
)

func TestPhoneProblem(t *testing.T) {
	cases := []struct {
		name, phone, want string // want 为空表示应通过
	}{
		{"美国号码合法", "+1 415 555 0142", ""},
		{"不带国家码的 10 位", "(415) 555-0142", ""},
		{"1 开头的 11 位", "1-415-555-0142", ""},
		{"国际号码合法", "+44 20 7946 0958", ""},
		{"区号以 0 开头", "+1 015 555 0142", "area code can't start with 0 or 1"},
		{"10 位区号以 1 开头", "1155550142", "area code can't start with 0 or 1"},
		{"交换码以 1 开头", "+1 415 155 0142", "exchange code can't start with 0 or 1"},
		{"+1 位数不足", "+1 415 555 014", "+1 and 10 digits"},
		{"美国全同数字", "+1 888 888 8888", "This number cannot be used"},
		{"国际全同数字", "+4444444444", "This number cannot be used"},
		{"格式错误", "abc", "with country code"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			got := phoneProblem(tc.phone)
			if (tc.want == "" && got != "") || (tc.want != "" && !strings.Contains(got, tc.want)) {
				t.Fatalf("phoneProblem(%q) = %q，期望 %q", tc.phone, got, tc.want)
			}
		})
	}
}

func TestBlacklistedSSN(t *testing.T) {
	for _, tc := range []struct {
		ssn  string
		want bool
	}{
		{"123-45-6789", true}, {"123456789", true}, {"111-11-1111", true}, {"999999999", true},
		{"234-56-7890", false}, {"111-11-1112", false}, {"12-345", false},
	} {
		if got := blacklistedSSN(tc.ssn); got != tc.want {
			t.Errorf("blacklistedSSN(%q) = %v", tc.ssn, got)
		}
	}
}
