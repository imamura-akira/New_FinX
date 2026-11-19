package dwmapper

// App 取值 → DW 取值对照表。
//
// 【全部待沙盒验证 / 待 DW 确认】DW 文档（creating-a-user）只给了部分示例，未给完整枚举。
// 策略（2026-11-19 用户确认）：先用最可能的取值，沙盒创建 User 报错时修正本文件，
// 并回写 design/pages.md 3.1.2 与 design/sandbox-log.md。业务代码不得绕过本文件写死 DW 取值。

// UserType：POST /users 顶层 userType（文档示例值）。
const UserType = "INDIVIDUAL_TRADER"

// countryAlpha3：ISO 3166-1 alpha-2 → alpha-3（DW 示例使用 "USA" 形式）。覆盖原型国家列表。
var countryAlpha3 = map[string]string{
	"US": "USA", "CN": "CHN", "HK": "HKG", "TW": "TWN", "SG": "SGP",
	"GB": "GBR", "CA": "CAN", "AU": "AUS", "JP": "JPN",
}

// tinTypeDW：IDENTIFICATION_INFO.type。非 SSN 类型需同时提供 issuingCountry（[D]）。
// DW userTaxIDType（post_users 参考页）：SSN、EIN、FTIN、PASSPORT、ALIEN_ID、OTHER。ITIN 无对应值，暂按 SSN 发送（待 DW 确认）。
var tinTypeDW = map[string]string{
	"SSN":         "SSN",
	"ITIN":        "SSN",
	"FOREIGN_TIN": "FTIN",
	"NIN":         "OTHER",
}

// employmentStatusDW：EMPLOYMENT_INFO.status。
var employmentStatusDW = map[string]string{
	"EMPLOYED":      "EMPLOYED",
	"SELF_EMPLOYED": "SELF_EMPLOYED",
	"UNEMPLOYED":    "UNEMPLOYED",
	"RETIRED":       "RETIRED",
	"STUDENT":       "STUDENT",
}

// investmentExperienceDW：INVESTOR_PROFILE_INFO.investmentExperience。
var investmentExperienceDW = map[string]string{
	"NONE": "NONE",
	"1-2":  "YRS_1_2",
	"3-5":  "YRS_3_5",
	"5+":   "YRS_5_10",
}

// investmentObjectiveDW：INVESTOR_PROFILE_INFO.investmentObjectives（post_users 参考页；LONG_TERM 等前四个已废弃）。
var investmentObjectiveDW = map[string]string{
	"GROWTH":   "GROWTH",
	"INCOME":   "INCOME",
	"PRESERVE": "CAPITAL_PRESERVATION",
	"SPEC":     "SPECULATION",
}

// riskToleranceDW：INVESTOR_PROFILE_INFO.riskTolerance。
var riskToleranceDW = map[string]string{
	"LOW":  "LOW",
	"MED":  "MODERATE",
	"HIGH": "HIGH",
}

// annualIncomeUSD / netWorthUSD：DW 示例中金额为数值；App 收集的是区间，取区间代表值（待 DW 确认是否接受区间枚举）。
var annualIncomeUSD = map[string]int{
	"<25k":      20000,
	"25k-50k":   37500,
	"50k-100k":  75000,
	"100k-200k": 150000,
	">200k":     250000,
}

var netWorthUSD = map[string]int{
	"<50k":      25000,
	"50k-200k":  125000,
	"200k-500k": 350000,
	"500k-1m":   750000,
	">1m":       1500000,
}

// fundingSourcesDW：COMPLIANCE_AML_INFO.fundingSources。
// 沙盒实测 "EMPLOYMENT" 被拒（U025 Unrecognized funding source）；DW 取值（post_users 参考页）：
// EMP、GIFT、TRUST、INVESTMENT、SAVINGS、RETIRE、GAMBLING、LEGAL、FAMILY、UNEMP、ROLLOVER、RENT、SALE、INSURANCE。
// 原型选项"经营收入"暂映射 EMP、"继承 / 赠与"映射 GIFT；"其他"在 DW 无对应值，不映射（提交时提示重新选择）。待用户确认选项调整。
var fundingSourcesDW = map[string]string{
	"EMPLOYMENT":  "EMP",
	"SAVINGS":     "SAVINGS",
	"INVESTMENTS": "INVESTMENT",
	"BUSINESS":    "EMP",
	"INHERITANCE": "GIFT",
}

// languageDW：BASIC_INFO.language（可选；DW 响应示例为 "en_US"）。
var languageDW = map[string]string{
	"zh_CN": "zh_CN",
	"zh_TW": "zh_TW",
	"en_US": "en_US",
}

// Allowed 返回 App 侧合法取值，供 application 包做提交校验，避免两处维护枚举。
func Allowed(field string) []string {
	var m map[string]string
	switch field {
	case "citizenship", "taxResidency", "country":
		m = countryAlpha3
	case "tinType":
		m = tinTypeDW
	case "employmentStatus":
		m = employmentStatusDW
	case "investmentExperience":
		m = investmentExperienceDW
	case "investmentObjective":
		m = investmentObjectiveDW
	case "riskTolerance":
		m = riskToleranceDW
	case "fundingSources":
		m = fundingSourcesDW
	case "language":
		m = languageDW
	case "annualIncomeRange":
		return keysInt(annualIncomeUSD)
	case "netWorthRange", "netWorthLiquidRange":
		return keysInt(netWorthUSD)
	default:
		return nil
	}
	out := make([]string, 0, len(m))
	for k := range m {
		out = append(out, k)
	}
	return out
}

func keysInt(m map[string]int) []string {
	out := make([]string, 0, len(m))
	for k := range m {
		out = append(out, k)
	}
	return out
}
