// Package orderrules：实盘（F14）与模拟盘（F15）共用的下单字段校验。
package orderrules

import (
	"encoding/json"
	"errors"
	"regexp"
	"strconv"
	"strings"
)

var limitRE = regexp.MustCompile(`^\d{1,7}(\.\d{1,4})?$`)

// Present：JSON 字段是否给了非 null 值。
func Present(raw json.RawMessage) bool {
	t := strings.TrimSpace(string(raw))
	return t != "" && t != "null"
}

// ParseLimitPrice：限价为 JSON number 且 > 0；$1 以上最多两位小数，$1 以下最多四位小数（美股最小报价单位）。
func ParseLimitPrice(raw json.RawMessage) (float64, error) {
	t := strings.TrimSpace(string(raw))
	if !Present(raw) || strings.HasPrefix(t, `"`) {
		return 0, errors.New("请输入限价")
	}
	if !limitRE.MatchString(t) {
		return 0, errors.New("限价格式不正确")
	}
	f, _ := strconv.ParseFloat(t, 64)
	if f <= 0 {
		return 0, errors.New("限价必须大于 0")
	}
	if dot := strings.IndexByte(t, '.'); f >= 1 && dot >= 0 && len(t)-dot-1 > 2 {
		return 0, errors.New("限价 $1 以上最多两位小数")
	}
	return f, nil
}

// FormatPrice：限价的十进制文本（不带多余的零），用于 DW 请求体与入库。
func FormatPrice(f float64) string { return strconv.FormatFloat(f, 'f', -1, 64) }
