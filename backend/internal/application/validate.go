package application

import (
	"regexp"
	"strings"
	"time"

	"github.com/imamura-akira/New_FinX/backend/internal/dwmapper"
	"github.com/imamura-akira/New_FinX/backend/internal/httpx"
)

// 提交时的完整校验。文案与原型 P-03 校验一致（api-spec.md 第 8 节 422xx），字段名为接口字段名。

var (
	asciiNameRE = regexp.MustCompile(`^[A-Za-z]+(?:[ '\-][A-Za-z]+)*$`)
	phoneRE     = regexp.MustCompile(`^\+?[\d\s\-()]{7,20}$`)
	emailRE     = regexp.MustCompile(`^[^\s@]+@[^\s@]+\.[^\s@]+$`)
	poBoxRE     = regexp.MustCompile(`(?i)\b(p\.?\s*o\.?\s*box|p\.?\s*o\.?\s*b\.?\s*\d|post\s+office\s+box|pmb\s*\d|po\s*box)\b|邮政信箱`)
	ssnRE       = regexp.MustCompile(`^\d{3}-?\d{2}-?\d{4}$`)
	itinRE      = regexp.MustCompile(`^9\d{2}-?\d{2}-?\d{4}$`)
)

// PartnerDisclosures：平台自有条款与 E-Sign 同意（P-05），提交时必须全部 accepted。
var PartnerDisclosures = []string{"p_terms", "p_privacy", "p_risk", "esign"}

func in(field, v string) bool {
	for _, a := range dwmapper.Allowed(field) {
		if a == v {
			return true
		}
	}
	return false
}

func ageOn(dob string, now time.Time) (int, bool) {
	d, err := time.Parse("2006-01-02", dob)
	if err != nil {
		return 0, false
	}
	age := now.Year() - d.Year()
	if now.Month() < d.Month() || (now.Month() == d.Month() && now.Day() < d.Day()) {
		age--
	}
	return age, true
}

// FullName：签名须与之一致。
func FullName(d dwmapper.Data) string {
	return strings.TrimSpace(strings.TrimSpace(d.FirstName) + " " + strings.TrimSpace(d.LastName))
}

// ValidateSubmission 返回全部字段错误（空切片表示通过）。
func ValidateSubmission(d dwmapper.Data, docs []DocMeta, disclosures []dwmapper.Disclosure, signature string, now time.Time) []httpx.FieldError {
	var fe []httpx.FieldError
	add := func(field, reason string) { fe = append(fe, httpx.FieldError{Field: field, Reason: reason}) }

	// P-03b 基本身份
	if !asciiNameRE.MatchString(d.FirstName) {
		add("firstName", "请使用英文字母填写，不支持 é、и、中文等非标准字符")
	}
	if !asciiNameRE.MatchString(d.LastName) {
		add("lastName", "请使用英文字母填写，不支持 é、и、中文等非标准字符")
	}
	switch age, ok := ageOn(d.DateOfBirth, now); {
	case !ok:
		add("dateOfBirth", "请选择出生日期")
	case age < 18:
		add("dateOfBirth", "开户人须年满 18 周岁")
	case age > 120:
		add("dateOfBirth", "请检查出生日期")
	}
	if !in("citizenship", d.Citizenship) {
		add("citizenship", "请选择国籍")
	}
	if !in("taxResidency", d.TaxResidency) {
		add("taxResidency", "请选择税务居民国家/地区")
	}
	if !phoneRE.MatchString(strings.TrimSpace(d.Phone)) {
		add("phone", "请输入有效的手机号（含国家区号）")
	}
	if !in("language", d.Language) {
		add("language", "请选择语言")
	}
	if ce := strings.TrimSpace(d.ContactEmail); ce != "" && !emailRE.MatchString(ce) {
		add("contactEmail", "请输入有效的联系邮箱")
	}

	// P-03c 税务
	switch d.USTaxPayer {
	case "YES", "NO":
	default:
		add("usTaxPayer", "请回答此问题")
	}
	tin := strings.TrimSpace(d.TIN)
	usTypes := map[string]bool{"SSN": true, "ITIN": true}
	switch {
	case d.USTaxPayer == "YES" && !usTypes[d.TINType], d.USTaxPayer == "NO" && (usTypes[d.TINType] || !in("tinType", d.TINType)):
		add("tinType", "请选择税号类型")
	case d.TINType == "SSN" && !ssnRE.MatchString(tin):
		add("tin", "SSN 格式应为 123-45-6789")
	case d.TINType == "ITIN" && !itinRE.MatchString(tin):
		add("tin", "ITIN 以 9 开头，格式为 9XX-XX-XXXX")
	case len(tin) < 5:
		add("tin", "请输入完整税号")
	}
	if d.USTaxPayer == "NO" && d.TaxTreaty != "YES" && d.TaxTreaty != "NO" {
		add("taxTreaty", "请回答此问题")
	}
	if !d.TINConfirm {
		add("tinConfirm", "请确认这是您本人报税使用的号码")
	}

	// P-03d 地址
	a := dwmapper.Address{}
	if d.ResidentialAddress != nil {
		a = *d.ResidentialAddress
	}
	switch {
	case strings.TrimSpace(a.Line1) == "":
		add("residentialAddress.line1", "请输入街道地址")
	case poBoxRE.MatchString(a.Line1 + " " + a.Line2):
		add("residentialAddress.line1", "居住地址不能是邮政信箱（P.O. Box），请填写实际居住地址")
	}
	if strings.TrimSpace(a.City) == "" {
		add("residentialAddress.city", "请输入城市")
	}
	if strings.TrimSpace(a.PostalCode) == "" {
		add("residentialAddress.postalCode", "请输入邮编")
	}
	if a.Country == "US" && strings.TrimSpace(a.State) == "" {
		add("residentialAddress.state", "请输入州")
	}
	if !in("country", a.Country) {
		add("residentialAddress.country", "请选择国家/地区")
	}
	if d.MailingAddress != nil && strings.TrimSpace(d.MailingAddress.Line1) == "" {
		add("mailingAddress.line1", "请输入邮寄地址")
	}

	// P-03e 就业与财务
	if !in("employmentStatus", d.EmploymentStatus) {
		add("employmentStatus", "请选择就业状态")
	}
	if (d.EmploymentStatus == "EMPLOYED" || d.EmploymentStatus == "SELF_EMPLOYED") && strings.TrimSpace(d.EmployerName) == "" {
		add("employerName", "在职时须填写雇主名称")
	}
	for _, c := range []struct{ field, v, msg string }{
		{"annualIncomeRange", d.AnnualIncomeRange, "请选择年收入"},
		{"netWorthRange", d.NetWorthRange, "请选择净资产"},
		{"netWorthLiquidRange", d.NetWorthLiquidRange, "请选择可投资（流动）净资产"},
		{"investmentExperience", d.InvestmentExperience, "请选择投资经验"},
		{"investmentObjective", d.InvestmentObjective, "请选择投资目标"},
		{"riskTolerance", d.RiskTolerance, "请选择风险承受能力"},
	} {
		if !in(c.field, c.v) {
			add(c.field, c.msg)
		}
	}
	okSources := len(d.FundingSources) > 0
	for _, s := range d.FundingSources {
		okSources = okSources && in("fundingSources", s)
	}
	if !okSources {
		add("fundingSources", "请至少选择一项资金来源")
	}

	// P-03f 监管问题
	if d.IsAffiliatedBD == nil {
		add("isAffiliatedBD", "请回答此问题")
	} else if *d.IsAffiliatedBD {
		if strings.TrimSpace(d.AffiliatedFirmName) == "" {
			add("affiliatedFirmName", "请填写机构名称")
		}
		if !d.AffiliatedAck {
			add("affiliatedAck", "请确认已了解报备要求")
		}
	}
	if d.IsPEP == nil {
		add("isPEP", "请回答此问题")
	} else if *d.IsPEP && strings.TrimSpace(d.PEPName) == "" {
		add("pepName", "请填写政治公众人物姓名")
	}
	if d.IsControlPerson == nil {
		add("isControlPerson", "请回答此问题")
	} else if *d.IsControlPerson && strings.TrimSpace(d.ControlCompanyName) == "" && strings.TrimSpace(d.ControlCompanySymbol) == "" {
		add("controlCompanyName", "请填写公司名称或股票代码")
	}

	// P-04 证件：非美国纳税人必须上传（护照只需资料页）
	if d.USTaxPayer == "NO" {
		sides := map[string]string{}
		for _, doc := range docs {
			sides[doc.Side] = doc.DocType
		}
		front, hasFront := sides["FRONT"]
		if !hasFront {
			add("documents", "请先上传证件照片")
		} else if _, hasBack := sides["BACK"]; front != "PASSPORT" && !hasBack {
			add("documents", "请上传证件背面")
		}
	}

	// P-05 披露与签名
	acks := map[string]dwmapper.Disclosure{}
	for _, x := range disclosures {
		acks[x.ID] = x
	}
	for _, id := range append(append([]string{}, dwmapper.DWRequiredDisclosures...), PartnerDisclosures...) {
		if !acks[id].Accepted {
			add("disclosures."+id, "请阅读并同意此文件")
		}
	}
	if _, answered := acks[dwmapper.DWChoiceDisclosure]; !answered {
		add("disclosures."+dwmapper.DWChoiceDisclosure, "请回答此问题")
	}
	if name := FullName(d); name == "" || !strings.EqualFold(strings.Join(strings.Fields(signature), " "), name) {
		add("signatureName", "签名须与法定姓名一致")
	}
	return fe
}
