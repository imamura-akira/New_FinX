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

// plausibleSSN：SSA 结构规则（区号不为 000/666/9xx、组号不为 00、序号不为 0000）及常见示例号码。
// 沙盒实测 DW 会拒绝无效 SSN（E032 Invalid SSN provided），在我方先拦截，避免申请被转人工。
func plausibleSSN(s string) bool {
	d := strings.NewReplacer("-", "", " ", "").Replace(s)
	if len(d) != 9 {
		return false
	}
	area, group, serial := d[:3], d[3:5], d[5:]
	if area == "000" || area == "666" || area[0] == '9' || group == "00" || serial == "0000" {
		return false
	}
	switch d {
	case "123456789", "078051120", "219099999":
		return false
	}
	return true
}

// blacklistedSSN：明显的占位号码（123-45-6789、全同数字），提示用户填写真实 SSN。
func blacklistedSSN(s string) bool {
	d := strings.NewReplacer("-", "", " ", "").Replace(s)
	return len(d) == 9 && (d == "123456789" || allSameDigit(d))
}

func allSameDigit(d string) bool {
	if d == "" {
		return false
	}
	return strings.Count(d, d[:1]) == len(d)
}

// phoneProblem 返回电话号码的问题文案（空表示通过）：
// 美国 / NANP（+1 开头，或不带国家码的 10 位、1 开头的 11 位）按 NANP 规则校验区号与交换码不以 0/1 开头；
// 任何号码的有效数字全同（如 +1 111 111 1111）一律拦截。
func phoneProblem(raw string) string {
	p := strings.TrimSpace(raw)
	if !phoneRE.MatchString(p) {
		return "Enter a valid phone number with country code"
	}
	digits := dwmapper.NormalizePhone(p)
	plus := strings.HasPrefix(digits, "+")
	digits = strings.TrimPrefix(digits, "+")
	national := ""
	switch {
	case plus && strings.HasPrefix(digits, "1"):
		national = digits[1:]
	case !plus && len(digits) == 11 && digits[0] == '1':
		national = digits[1:]
	case !plus && len(digits) == 10:
		national = digits
	}
	if national != "" {
		if len(national) != 10 {
			return "Enter a valid U.S. phone number: +1 and 10 digits"
		}
		if allSameDigit(national) {
			return "Enter your real phone number. This number cannot be used."
		}
		if national[0] == '0' || national[0] == '1' {
			return "Enter a valid U.S. phone number: the area code can't start with 0 or 1"
		}
		if national[3] == '0' || national[3] == '1' {
			return "Enter a valid U.S. phone number: the exchange code can't start with 0 or 1"
		}
		return ""
	}
	if allSameDigit(digits) {
		return "Enter your real phone number. This number cannot be used."
	}
	return ""
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
		add("firstName", "Use standard ASCII letters only (no é, и, Chinese, etc.)")
	}
	if !asciiNameRE.MatchString(d.LastName) {
		add("lastName", "Use standard ASCII letters only (no é, и, Chinese, etc.)")
	}
	switch age, ok := ageOn(d.DateOfBirth, now); {
	case !ok:
		add("dateOfBirth", "Select your date of birth")
	case age < 18:
		add("dateOfBirth", "You must be 18 or older to open an account")
	case age > 120:
		add("dateOfBirth", "Check your date of birth")
	}
	if !in("citizenship", d.Citizenship) {
		add("citizenship", "Select your citizenship")
	}
	if !in("taxResidency", d.TaxResidency) {
		add("taxResidency", "Select your country of tax residence")
	}
	if msg := phoneProblem(d.Phone); msg != "" {
		add("phone", msg)
	}
	if !in("language", d.Language) {
		add("language", "Select a language")
	}
	if ce := strings.TrimSpace(d.ContactEmail); ce != "" && !emailRE.MatchString(ce) {
		add("contactEmail", "Enter a valid contact email")
	}

	// P-03c 税务
	switch d.USTaxPayer {
	case "YES", "NO":
	default:
		add("usTaxPayer", "Please answer this question")
	}
	tin := strings.TrimSpace(d.TIN)
	usTypes := map[string]bool{"SSN": true, "ITIN": true}
	switch {
	case d.USTaxPayer == "YES" && !usTypes[d.TINType], d.USTaxPayer == "NO" && (usTypes[d.TINType] || !in("tinType", d.TINType)):
		add("tinType", "Select a tax ID type")
	case d.TINType == "SSN" && !ssnRE.MatchString(tin):
		add("tin", "SSN format: 123-45-6789")
	case d.TINType == "SSN" && blacklistedSSN(tin):
		add("tin", "Enter your real SSN. This number cannot be used.")
	case d.TINType == "SSN" && !plausibleSSN(tin):
		add("tin", "This SSN is not valid. Check it and try again")
	case d.TINType == "ITIN" && !itinRE.MatchString(tin):
		add("tin", "ITIN starts with 9: 9XX-XX-XXXX")
	case len(tin) < 5:
		add("tin", "Enter your full tax ID")
	}
	if d.USTaxPayer == "NO" && d.TaxTreaty != "YES" && d.TaxTreaty != "NO" {
		add("taxTreaty", "Please answer this question")
	}
	if !d.TINConfirm {
		add("tinConfirm", "Confirm this is the number you use to file taxes")
	}

	// P-03d 地址
	a := dwmapper.Address{}
	if d.ResidentialAddress != nil {
		a = *d.ResidentialAddress
	}
	switch {
	case strings.TrimSpace(a.Line1) == "":
		add("residentialAddress.line1", "Enter your street address")
	case poBoxRE.MatchString(a.Line1 + " " + a.Line2):
		add("residentialAddress.line1", "Home address cannot be a P.O. Box — enter where you actually live")
	}
	if strings.TrimSpace(a.City) == "" {
		add("residentialAddress.city", "Enter your city")
	}
	if strings.TrimSpace(a.PostalCode) == "" {
		add("residentialAddress.postalCode", "Enter your ZIP / postal code")
	}
	if a.Country == "US" {
		if strings.TrimSpace(a.State) == "" {
			add("residentialAddress.state", "Enter your state")
		} else if _, ok := dwmapper.NormalizeUSState(a.State); !ok { // 沙盒 E032：province 须为 USPS 州代码
			add("residentialAddress.state", "Enter a valid U.S. state, e.g. CA or California")
		}
	}
	if !in("country", a.Country) {
		add("residentialAddress.country", "Select your country or region")
	}
	if d.MailingAddress != nil && strings.TrimSpace(d.MailingAddress.Line1) == "" {
		add("mailingAddress.line1", "Enter your mailing address")
	}

	// P-03e 就业与财务
	if !in("employmentStatus", d.EmploymentStatus) {
		add("employmentStatus", "Select your employment status")
	}
	if d.EmploymentStatus == "EMPLOYED" || d.EmploymentStatus == "SELF_EMPLOYED" {
		if strings.TrimSpace(d.EmployerName) == "" {
			add("employerName", "Employer name is required when employed")
		}
		if !in("industry", d.Industry) { // 沙盒实测：开户必需
			add("industry", "Select your industry")
		}
		if d.Position != "" && !in("position", d.Position) {
			add("position", "Select a position from the list")
		}
	}
	for _, c := range []struct{ field, v, msg string }{
		{"annualIncomeRange", d.AnnualIncomeRange, "Select your annual income"},
		{"netWorthRange", d.NetWorthRange, "Select your net worth"},
		{"netWorthLiquidRange", d.NetWorthLiquidRange, "Select your liquid net worth"},
		{"investmentExperience", d.InvestmentExperience, "Select your investment experience"},
		{"investmentObjective", d.InvestmentObjective, "Select your investment objective"},
		{"riskTolerance", d.RiskTolerance, "Select your risk tolerance"},
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
		add("fundingSources", "Select at least one source of funds")
	}

	// P-03f 监管问题
	if d.IsAffiliatedBD == nil {
		add("isAffiliatedBD", "Please answer this question")
	} else if *d.IsAffiliatedBD {
		if strings.TrimSpace(d.AffiliatedFirmName) == "" {
			add("affiliatedFirmName", "Enter the firm name")
		}
		if !d.AffiliatedAck {
			add("affiliatedAck", "Confirm you understand the notification requirements")
		}
	}
	if d.IsPEP == nil {
		add("isPEP", "Please answer this question")
	} else if *d.IsPEP && strings.TrimSpace(d.PEPName) == "" {
		add("pepName", "Enter the name of the PEP")
	}
	if d.IsControlPerson == nil {
		add("isControlPerson", "Please answer this question")
	} else if *d.IsControlPerson && strings.TrimSpace(d.ControlCompanyName) == "" && strings.TrimSpace(d.ControlCompanySymbol) == "" {
		add("controlCompanyName", "Enter the company name or ticker")
	}

	// P-04 证件：非美国纳税人必须上传（护照只需资料页）
	if d.USTaxPayer == "NO" {
		sides := map[string]string{}
		for _, doc := range docs {
			sides[doc.Side] = doc.DocType
		}
		front, hasFront := sides["FRONT"]
		if !hasFront {
			add("documents", "Please upload your ID photos first")
		} else if _, hasBack := sides["BACK"]; front != "PASSPORT" && !hasBack {
			add("documents", "Upload the back of your ID")
		}
	}

	// P-05 披露与签名
	acks := map[string]dwmapper.Disclosure{}
	for _, x := range disclosures {
		acks[x.ID] = x
	}
	for _, id := range append(append([]string{}, dwmapper.DWRequiredDisclosures...), PartnerDisclosures...) {
		if !acks[id].Accepted {
			add("disclosures."+id, "Read and agree to this document")
		}
	}
	if _, answered := acks[dwmapper.DWChoiceDisclosure]; !answered {
		add("disclosures."+dwmapper.DWChoiceDisclosure, "Please answer this question")
	}
	if name := FullName(d); name == "" || !strings.EqualFold(strings.Join(strings.Fields(signature), " "), name) {
		add("signatureName", "Signature must match your legal name")
	}
	return fe
}

// validationEN：开户模块的 42200（标题文案取自原型 toast "Please fix the highlighted fields"）。
func validationEN(fe ...httpx.FieldError) error {
	return httpx.Validation("Please fix the highlighted fields", fe...)
}
