package dwmapper

import "strings"

// usStates：美国地址 ADDRESS_INFO.province 允许的 USPS 两位代码（50 州 + DC + 海外领地）。
// 沙盒实测（2026-11-20）：province 传州全称等非代码值时 POST /users 返回 E032 "Invalid US state"。
var usStates = map[string]string{
	"AL": "Alabama", "AK": "Alaska", "AZ": "Arizona", "AR": "Arkansas", "CA": "California",
	"CO": "Colorado", "CT": "Connecticut", "DE": "Delaware", "FL": "Florida", "GA": "Georgia",
	"HI": "Hawaii", "ID": "Idaho", "IL": "Illinois", "IN": "Indiana", "IA": "Iowa",
	"KS": "Kansas", "KY": "Kentucky", "LA": "Louisiana", "ME": "Maine", "MD": "Maryland",
	"MA": "Massachusetts", "MI": "Michigan", "MN": "Minnesota", "MS": "Mississippi", "MO": "Missouri",
	"MT": "Montana", "NE": "Nebraska", "NV": "Nevada", "NH": "New Hampshire", "NJ": "New Jersey",
	"NM": "New Mexico", "NY": "New York", "NC": "North Carolina", "ND": "North Dakota", "OH": "Ohio",
	"OK": "Oklahoma", "OR": "Oregon", "PA": "Pennsylvania", "RI": "Rhode Island", "SC": "South Carolina",
	"SD": "South Dakota", "TN": "Tennessee", "TX": "Texas", "UT": "Utah", "VT": "Vermont",
	"VA": "Virginia", "WA": "Washington", "WV": "West Virginia", "WI": "Wisconsin", "WY": "Wyoming",
	"DC": "District of Columbia",
	"PR": "Puerto Rico", "GU": "Guam", "VI": "U.S. Virgin Islands", "AS": "American Samoa", "MP": "Northern Mariana Islands",
}

// usStateByName：全称及常见写法（小写、去标点）→ 代码。
var usStateByName = func() map[string]string {
	m := map[string]string{}
	for code, name := range usStates {
		m[stateKey(name)] = code
	}
	m["washington dc"] = "DC"
	m["washington d c"] = "DC"
	m["virgin islands"] = "VI"
	return m
}()

func stateKey(s string) string {
	s = strings.ToLower(strings.TrimSpace(s))
	s = strings.NewReplacer(".", " ", ",", " ", "-", " ").Replace(s)
	return strings.Join(strings.Fields(s), " ")
}

// NormalizeUSState 把美国州的输入规范为 USPS 两位代码：接受代码（大小写不限）或全称（如 "california"）。
// 无法识别时 ok=false。
func NormalizeUSState(s string) (code string, ok bool) {
	t := strings.TrimSpace(s)
	if up := strings.ToUpper(strings.ReplaceAll(t, ".", "")); len(up) == 2 {
		if _, found := usStates[up]; found {
			return up, true
		}
	}
	if code, found := usStateByName[stateKey(t)]; found {
		return code, true
	}
	return "", false
}
