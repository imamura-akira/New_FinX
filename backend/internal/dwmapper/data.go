// Package dwmapper：App 开户字段 → DW documents 映射。唯一依据是 design/pages.md 3.1.2。
//
// App 不感知 DW 字段名；App 侧字段名以 openapi.yaml 的 ApplicationData 为准（api-spec.md 第 10 节）。
// 所有 DW 枚举取值集中在 enums.go，均为"待沙盒验证 / 待 DW 确认"。
package dwmapper

// Address：居住地址 / 邮寄地址。
type Address struct {
	Line1      string `json:"line1,omitempty"`
	Line2      string `json:"line2,omitempty"`
	City       string `json:"city,omitempty"`
	State      string `json:"state,omitempty"`
	PostalCode string `json:"postalCode,omitempty"`
	Country    string `json:"country,omitempty"` // ISO 3166-1 alpha-2
}

// PEPRole：pepRoles[]。
type PEPRole struct {
	Role      string `json:"role,omitempty"`
	StartYear int    `json:"startYear,omitempty"`
	EndYear   int    `json:"endYear,omitempty"`
}

// Data：ApplicationData。是/否问题用 *bool 区分"未回答"。
type Data struct {
	// P-03b 基本身份
	FirstName    string `json:"firstName,omitempty"`
	LastName     string `json:"lastName,omitempty"`
	DateOfBirth  string `json:"dateOfBirth,omitempty"` // YYYY-MM-DD
	Citizenship  string `json:"citizenship,omitempty"`
	TaxResidency string `json:"taxResidency,omitempty"`
	Phone        string `json:"phone,omitempty"`
	ContactEmail string `json:"contactEmail,omitempty"`
	Language     string `json:"language,omitempty"`

	// P-03c 税务
	USTaxPayer string `json:"usTaxPayer,omitempty"` // YES / NO
	TINType    string `json:"tinType,omitempty"`    // SSN / ITIN / FOREIGN_TIN / NIN
	TIN        string `json:"tin,omitempty"`
	TaxTreaty  string `json:"taxTreaty,omitempty"` // YES / NO（非美国纳税人）
	IRSBackup  string `json:"irsBackup,omitempty"` // YES / NO（美国纳税人）
	TINConfirm bool   `json:"tinConfirm,omitempty"`

	// P-03d 地址
	ResidentialAddress *Address `json:"residentialAddress,omitempty"`
	MailingAddress     *Address `json:"mailingAddress,omitempty"`

	// P-03e 就业与财务
	EmploymentStatus     string   `json:"employmentStatus,omitempty"`
	EmployerName         string   `json:"employerName,omitempty"`
	Occupation           string   `json:"occupation,omitempty"` // 已停用（自由文本），不发送给 DW
	Industry             string   `json:"industry,omitempty"`   // DW EMPLOYMENT_INFO.type
	Position             string   `json:"position,omitempty"`   // DW EMPLOYMENT_INFO.position
	AnnualIncomeRange    string   `json:"annualIncomeRange,omitempty"`
	NetWorthRange        string   `json:"netWorthRange,omitempty"`
	NetWorthLiquidRange  string   `json:"netWorthLiquidRange,omitempty"`
	InvestmentExperience string   `json:"investmentExperience,omitempty"`
	InvestmentObjective  string   `json:"investmentObjective,omitempty"`
	RiskTolerance        string   `json:"riskTolerance,omitempty"`
	FundingSources       []string `json:"fundingSources,omitempty"`

	// P-03f 监管问题
	IsAffiliatedBD       *bool     `json:"isAffiliatedBD,omitempty"`
	AffiliatedFirmName   string    `json:"affiliatedFirmName,omitempty"`
	AffiliatedAck        bool      `json:"affiliatedAck,omitempty"`
	IsPEP                *bool     `json:"isPEP,omitempty"`
	PEPName              string    `json:"pepName,omitempty"`
	PEPCountry           string    `json:"pepCountry,omitempty"`
	PEPRoles             []PEPRole `json:"pepRoles,omitempty"`
	IsControlPerson      *bool     `json:"isControlPerson,omitempty"`
	ControlCompanyName   string    `json:"controlCompanyName,omitempty"`
	ControlCompanySymbol string    `json:"controlCompanySymbol,omitempty"`

	// P-03g 账户类型（首期固定 LIVE / CASH / SELF；映射时不读取客户端值）
	AccountType           string `json:"accountType,omitempty"`
	TradingType           string `json:"tradingType,omitempty"`
	AccountManagementType string `json:"accountManagementType,omitempty"`
}

// IsUSTaxPayer：美国纳税人由 DW 用税号核验，无需上传证件（pages.md 3.1.3）。
func (d Data) IsUSTaxPayer() bool { return d.USTaxPayer == "YES" }

// Disclosure：P-05 单项确认（openapi DisclosureAck）。Accepted 对 rule14b 表示用户的选择。
type Disclosure struct {
	ID         string `json:"id"`
	Source     string `json:"source,omitempty"` // DW / PARTNER
	Version    string `json:"version,omitempty"`
	Accepted   bool   `json:"accepted"`
	AcceptedAt string `json:"acceptedAt,omitempty"`
}

// DW DISCLOSURES 字段（pages.md 3.1.4）。
var (
	DWRequiredDisclosures = []string{"termsOfUse", "customerAgreement", "marketDataAgreement", "privacyPolicy", "dataSharing"}
	DWOptionalDisclosures = []string{"extendedHoursAgreement"}
)

// DWChoiceDisclosure：Rule 14b-1(c) 是/否选择，必须作答，选"否"不影响开户。
const DWChoiceDisclosure = "rule14b"
