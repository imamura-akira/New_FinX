package dwmapper

import (
	"fmt"
	"regexp"
	"sort"
	"strings"
	"time"
)

// Document：DW documents[] 元素。
type Document struct {
	Type string         `json:"type"`
	Data map[string]any `json:"data"`
}

// DW document 类型（pages.md 3.1.2）。
const (
	DocBasicInfo       = "BASIC_INFO"
	DocIdentification  = "IDENTIFICATION_INFO"
	DocPersonalInfo    = "PERSONAL_INFO"
	DocAddressInfo     = "ADDRESS_INFO"
	DocEmploymentInfo  = "EMPLOYMENT_INFO"
	DocInvestorProfile = "INVESTOR_PROFILE_INFO"
	DocComplianceAML   = "COMPLIANCE_AML_INFO"
	DocDisclosures     = "DISCLOSURES"
	DocTaxInfo         = "TAX_INFO"
)

// CoreTypes：POST /users 首次提交的四类（已核实 creating-a-user）；其余由 PATCH /users/{userID} 补充。
var CoreTypes = []string{DocBasicInfo, DocIdentification, DocPersonalInfo, DocAddressInfo}

// dwNull：DW 示例中"无"用字符串 "NULL" 表示（仅见于 politicallyExposedNames 示例，其他字段沿用，待 DW 确认）。
const dwNull = "NULL"

// Submission：除开户资料外，映射还需要的提交信息。
type Submission struct {
	Disclosures []Disclosure
	SignedBy    string // P-05 签名（已由 application 校验与法定姓名一致）
	LoginEmail  string // contactEmail 为空时的回退
}

// MappingError 列出无法映射的字段名（只含字段名，不含取值，可安全写日志）。
type MappingError struct{ Fields []string }

func (e *MappingError) Error() string {
	return "dwmapper: 以下字段无法映射为 DW 取值: " + strings.Join(e.Fields, ", ")
}

// Build 生成全部 DW documents，按 pages.md 3.1.2 表的顺序返回 core（POST）与 rest（PATCH）。
// 不做完整性校验（由 application 在提交时完成），只在取值无法映射时返回 *MappingError。
func Build(d Data, s Submission) (core, rest []Document, err error) {
	m := &mapper{}
	addr := Address{}
	if d.ResidentialAddress != nil {
		addr = *d.ResidentialAddress
	}

	email := strings.TrimSpace(d.ContactEmail)
	if email == "" {
		email = strings.TrimSpace(s.LoginEmail)
	}
	basic := map[string]any{
		"firstName":    strings.TrimSpace(d.FirstName),
		"lastName":     strings.TrimSpace(d.LastName),
		"country":      m.lookup("residentialAddress.country", countryAlpha3, addr.Country),
		"phone":        NormalizePhone(d.Phone),
		"emailAddress": email,
	}
	if lang, ok := languageDW[d.Language]; ok {
		basic["language"] = lang
	}

	tinType := m.lookup("tinType", tinTypeDW, d.TINType)
	ident := map[string]any{
		"value":       NormalizeTIN(d.TINType, d.TIN),
		"type":        tinType,
		"citizenship": m.lookup("citizenship", countryAlpha3, d.Citizenship),
	}
	if tinType != "SSN" { // [D] "non-SSN types require issuingCountry"
		ident["issuingCountry"] = m.lookup("taxResidency", countryAlpha3, d.TaxResidency)
	}

	personal := map[string]any{"politicallyExposedNames": dwNull}
	if dob, perr := time.Parse("2006-01-02", d.DateOfBirth); perr == nil {
		personal["birthDay"], personal["birthMonth"], personal["birthYear"] = dob.Day(), int(dob.Month()), dob.Year()
	} else {
		m.fail("dateOfBirth")
	}
	if isTrue(d.IsPEP) {
		personal["politicallyExposedNames"] = strings.TrimSpace(d.PEPName)
	}
	if d.IsUSTaxPayer() { // irsBackupWithholdings 不在 DW 文档页中（[G]），待 DW 确认
		personal["irsBackupWithholdings"] = d.IRSBackup == "YES"
	}

	address := map[string]any{
		"street1":    strings.TrimSpace(addr.Line1),
		"city":       strings.TrimSpace(addr.City),
		"province":   strings.TrimSpace(addr.State),
		"postalCode": strings.TrimSpace(addr.PostalCode),
		"country":    m.lookup("residentialAddress.country", countryAlpha3, addr.Country),
	}
	if l2 := strings.TrimSpace(addr.Line2); l2 != "" {
		address["street2"] = l2
	}

	employment := map[string]any{
		"status":     m.lookup("employmentStatus", employmentStatusDW, d.EmploymentStatus),
		"broker":     isTrue(d.IsAffiliatedBD),
		"directorOf": dwNull,
	}
	if isTrue(d.IsControlPerson) {
		employment["directorOf"] = directorOf(d.ControlCompanyName, d.ControlCompanySymbol)
	}
	if d.EmploymentStatus == "EMPLOYED" || d.EmploymentStatus == "SELF_EMPLOYED" { // company / position 不在 DW 文档页中（[G]）
		employment["company"] = strings.TrimSpace(d.EmployerName)
		if p := strings.TrimSpace(d.Occupation); p != "" {
			employment["position"] = p
		}
	}

	investor := map[string]any{
		"investmentExperience": m.lookup("investmentExperience", investmentExperienceDW, d.InvestmentExperience),
		"annualIncome":         m.lookupInt("annualIncomeRange", annualIncomeUSD, d.AnnualIncomeRange),
		"networthTotal":        m.lookupInt("netWorthRange", netWorthUSD, d.NetWorthRange),
		"networthLiquid":       m.lookupInt("netWorthLiquidRange", netWorthUSD, d.NetWorthLiquidRange),
		"riskTolerance":        m.lookup("riskTolerance", riskToleranceDW, d.RiskTolerance),
		"investmentObjectives": m.lookup("investmentObjective", investmentObjectiveDW, d.InvestmentObjective),
	}

	sources := make([]string, 0, len(d.FundingSources))
	for _, f := range d.FundingSources {
		sources = append(sources, m.lookup("fundingSources", fundingSourcesDW, f))
	}
	aml := map[string]any{"fundingSources": sources}

	disc := map[string]any{"signedBy": strings.TrimSpace(s.SignedBy)}
	acks := map[string]Disclosure{}
	for _, a := range s.Disclosures {
		acks[a.ID] = a
	}
	for _, id := range DWRequiredDisclosures {
		disc[id] = acks[id].Accepted
	}
	disc[DWChoiceDisclosure] = acks[DWChoiceDisclosure].Accepted
	for _, id := range DWOptionalDisclosures {
		if acks[id].Accepted {
			disc[id] = true
		}
	}

	tax := map[string]any{ // usTaxpayer 归属 TAX_INFO 还是 IDENTIFICATION_INFO 待 DW 确认（[C][D]）
		"usTaxpayer":      d.IsUSTaxPayer(),
		"taxTreatyWithUS": !d.IsUSTaxPayer() && d.TaxTreaty == "YES",
	}

	if len(m.bad) > 0 {
		return nil, nil, &MappingError{Fields: m.sorted()}
	}
	core = []Document{
		{DocBasicInfo, basic}, {DocIdentification, ident}, {DocPersonalInfo, personal}, {DocAddressInfo, address},
	}
	rest = []Document{
		{DocEmploymentInfo, employment}, {DocInvestorProfile, investor}, {DocComplianceAML, aml},
		{DocDisclosures, disc}, {DocTaxInfo, tax},
	}
	return core, rest, nil
}

// CreateUserBody：POST /users 请求体。username / password 由后端生成【Q-DW-4】。
func CreateUserBody(username, password string, docs []Document) map[string]any {
	return map[string]any{"userType": UserType, "username": username, "password": password, "documents": docs}
}

// PatchUserBody：PATCH /users/{userID} 请求体。
func PatchUserBody(docs []Document) map[string]any {
	return map[string]any{"documents": docs}
}

var nonDigit = regexp.MustCompile(`\D`)

// NormalizeTIN：SSN / ITIN 只保留数字（123-45-6789 → 123456789）；其他类型去掉空白。
func NormalizeTIN(tinType, tin string) string {
	if tinType == "SSN" || tinType == "ITIN" {
		return nonDigit.ReplaceAllString(tin, "")
	}
	return strings.Join(strings.Fields(tin), "")
}

// NormalizePhone：保留开头的 + 与数字（"+1 415 555-0142" → "+14155550142"），DW 期望格式待沙盒验证。
func NormalizePhone(p string) string {
	p = strings.TrimSpace(p)
	plus := strings.HasPrefix(p, "+")
	digits := nonDigit.ReplaceAllString(p, "")
	if plus {
		return "+" + digits
	}
	return digits
}

func directorOf(name, symbol string) string {
	name, symbol = strings.TrimSpace(name), strings.ToUpper(strings.TrimSpace(symbol))
	switch {
	case name != "" && symbol != "":
		return name + " (" + symbol + ")"
	case name != "":
		return name
	case symbol != "":
		return symbol
	}
	return dwNull
}

func isTrue(b *bool) bool { return b != nil && *b }

type mapper struct{ bad map[string]bool }

func (m *mapper) fail(field string) {
	if m.bad == nil {
		m.bad = map[string]bool{}
	}
	m.bad[field] = true
}

func (m *mapper) lookup(field string, table map[string]string, v string) string {
	if out, ok := table[v]; ok {
		return out
	}
	m.fail(field)
	return ""
}

func (m *mapper) lookupInt(field string, table map[string]int, v string) int {
	if out, ok := table[v]; ok {
		return out
	}
	m.fail(field)
	return 0
}

func (m *mapper) sorted() []string {
	out := make([]string, 0, len(m.bad))
	for k := range m.bad {
		out = append(out, k)
	}
	sort.Strings(out)
	return out
}

// String 便于调试输出（不打印 data，避免 PII 进日志）。
func (d Document) String() string { return fmt.Sprintf("Document{%s, %d fields}", d.Type, len(d.Data)) }
