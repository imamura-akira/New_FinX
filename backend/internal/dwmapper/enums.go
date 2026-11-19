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

// industryDW：EMPLOYMENT_INFO.type（post_users 参考页，19 项；App 代码与 DW 一致）。
// 沙盒实测：缺少 type 时 POST /accounts 返回 U040，受雇/自雇时必填。
var industryDW = map[string]string{
	"AGRICULTURE":   "AGRICULTURE",
	"MINING":        "MINING",
	"UTILITIES":     "UTILITIES",
	"CONSTRUCTION":  "CONSTRUCTION",
	"MANUFACTURING": "MANUFACTURING",
	"WHOLESALE":     "WHOLESALE",
	"RETAIL":        "RETAIL",
	"TRANSPORT":     "TRANSPORT",
	"INFORMATION":   "INFORMATION",
	"FINANCE":       "FINANCE",
	"REAL_ESTATE":   "REAL_ESTATE",
	"PROFESSIONAL":  "PROFESSIONAL",
	"MANAGEMENT":    "MANAGEMENT",
	"EDUCATION":     "EDUCATION",
	"HEALTH":        "HEALTH",
	"ART":           "ART",
	"FOOD":          "FOOD",
	"PUBLIC":        "PUBLIC",
	"WASTE":         "WASTE",
}

// positionDW：EMPLOYMENT_INFO.position（post_users 参考页，89 项；DW 无 OTHER）。选填。
var positionDW = map[string]string{
	"ACCOUNTANT":       "ACCOUNTANT",
	"ACTUARY":          "ACTUARY",
	"ADJUSTER":         "ADJUSTER",
	"ADMINISTRATOR":    "ADMINISTRATOR",
	"ADVERTISER":       "ADVERTISER",
	"AGENT":            "AGENT",
	"ATC":              "ATC",
	"AMBASSADOR":       "AMBASSADOR",
	"ANALYST":          "ANALYST",
	"APPRAISER":        "APPRAISER",
	"ARCHITECT":        "ARCHITECT",
	"ARTIST":           "ARTIST",
	"ASSISTANT":        "ASSISTANT",
	"ATHLETE":          "ATHLETE",
	"ATTENDANT":        "ATTENDANT",
	"ATTORNEY":         "ATTORNEY",
	"AUCTIONEER":       "AUCTIONEER",
	"AUDITOR":          "AUDITOR",
	"BARBER":           "BARBER",
	"BROKER":           "BROKER",
	"BUSINESS_EXEC":    "BUSINESS_EXEC",
	"BUSINESS_OWNER":   "BUSINESS_OWNER",
	"CAREGIVER":        "CAREGIVER",
	"CARPENTER":        "CARPENTER",
	"CASHIER":          "CASHIER",
	"CHEF":             "CHEF",
	"CHIROPRACTOR":     "CHIROPRACTOR",
	"CIVIL":            "CIVIL",
	"CLERGY":           "CLERGY",
	"CLERK":            "CLERK",
	"COMPLIANCE":       "COMPLIANCE",
	"CONSULTANT":       "CONSULTANT",
	"CONTRACTOR":       "CONTRACTOR",
	"COUNSELOR":        "COUNSELOR",
	"CUSTOMER_SERVICE": "CUSTOMER_SERVICE",
	"DEALER":           "DEALER",
	"DEVELOPER":        "DEVELOPER",
	"DISTRIBUTOR":      "DISTRIBUTOR",
	"DOCTOR":           "DOCTOR",
	"DRIVER":           "DRIVER",
	"ENGINEER":         "ENGINEER",
	"EXAMINER":         "EXAMINER",
	"EXTERMINATOR":     "EXTERMINATOR",
	"FACTORY":          "FACTORY",
	"FARMER":           "FARMER",
	"FINANCIAL":        "FINANCIAL",
	"FISHERMAN":        "FISHERMAN",
	"FLIGHT":           "FLIGHT",
	"HR":               "HR",
	"IMPEX":            "IMPEX",
	"INSPECTOR":        "INSPECTOR",
	"INTERN":           "INTERN",
	"INVESTMENT":       "INVESTMENT",
	"INVESTOR":         "INVESTOR",
	"IT":               "IT",
	"JANITOR":          "JANITOR",
	"JEWELER":          "JEWELER",
	"LABORER":          "LABORER",
	"LANDSCAPER":       "LANDSCAPER",
	"LENDING":          "LENDING",
	"MANAGER":          "MANAGER",
	"MECHANIC":         "MECHANIC",
	"MILITARY":         "MILITARY",
	"MORTICIAN":        "MORTICIAN",
	"NURSE":            "NURSE",
	"NUTRITIONIST":     "NUTRITIONIST",
	"OFFICE":           "OFFICE",
	"PHARMACIST":       "PHARMACIST",
	"PHYSICAL":         "PHYSICAL",
	"PILOT":            "PILOT",
	"POLICE":           "POLICE",
	"POLITICIAN":       "POLITICIAN",
	"PM":               "PM",
	"REP":              "REP",
	"RESEARCHER":       "RESEARCHER",
	"SAILOR":           "SAILOR",
	"SALES":            "SALES",
	"SCIENTIST":        "SCIENTIST",
	"SEAMSTRESS":       "SEAMSTRESS",
	"SECURITY":         "SECURITY",
	"SOCIAL":           "SOCIAL",
	"TEACHER":          "TEACHER",
	"TECHNICIAN":       "TECHNICIAN",
	"TELLER":           "TELLER",
	"TRADESPERSON":     "TRADESPERSON",
	"TRAINER":          "TRAINER",
	"TRANSPORTER":      "TRANSPORTER",
	"UNDERWRITER":      "UNDERWRITER",
	"WRITER":           "WRITER",
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
// 2026-11-19 用户决定：P-03e 选项与 DW 取值一一对应（App 取值即 DW 取值），删除 Other 与"经营收入"近似映射。
// 沙盒实测 "EMPLOYMENT" 被拒、"EMP" 被接受；其余取值来自 post_users 参考页（ui-signoff.md 第 3 节登记）。
var fundingSourcesDW = map[string]string{
	"EMP":        "EMP",        // Employment income
	"SAVINGS":    "SAVINGS",    // Savings
	"INVESTMENT": "INVESTMENT", // Investment returns
	"GIFT":       "GIFT",       // Gift / Inheritance
	"RETIRE":     "RETIRE",     // Retirement
	"FAMILY":     "FAMILY",     // Family support
	"SALE":       "SALE",       // Sale of assets
	"RENT":       "RENT",       // Rental income
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
	case "industry":
		m = industryDW
	case "position":
		m = positionDW
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
