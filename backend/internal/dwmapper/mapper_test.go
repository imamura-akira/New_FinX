package dwmapper

import (
	"encoding/json"
	"reflect"
	"sort"
	"strings"
	"testing"

	"github.com/imamura-akira/New_FinX/backend/api"
	"gopkg.in/yaml.v3"
)

// 测试数据全部为虚构占位值。
func ptr(b bool) *bool { return &b }

func usData() Data {
	return Data{
		FirstName: "Alex", LastName: "Chen", DateOfBirth: "1990-03-07",
		Citizenship: "US", TaxResidency: "US", Phone: "+1 415 555-0142", ContactEmail: "alex@example.com", Language: "zh_CN",
		USTaxPayer: "YES", TINType: "SSN", TIN: "123-45-6789", IRSBackup: "NO", TINConfirm: true,
		ResidentialAddress: &Address{Line1: "200 Market Street", Line2: "Apt 5B", City: "San Francisco", State: "CA", PostalCode: "94105", Country: "US"},
		EmploymentStatus:   "EMPLOYED", EmployerName: "Example Corp", Industry: "PROFESSIONAL", Position: "ENGINEER",
		AnnualIncomeRange: "100k-200k", NetWorthRange: "200k-500k", NetWorthLiquidRange: "50k-200k",
		InvestmentExperience: "3-5", InvestmentObjective: "GROWTH", RiskTolerance: "MED",
		FundingSources: []string{"EMP", "SAVINGS"},
		IsAffiliatedBD: ptr(false), IsPEP: ptr(false), IsControlPerson: ptr(false),
	}
}

func intlData() Data {
	d := usData()
	d.Citizenship, d.TaxResidency = "SG", "SG"
	d.USTaxPayer, d.TINType, d.TIN, d.IRSBackup, d.TaxTreaty = "NO", "FOREIGN_TIN", " S1234 567D ", "", "YES"
	d.ResidentialAddress = &Address{Line1: "1 Example Road", City: "Singapore", PostalCode: "000001", Country: "SG"}
	return d
}

func sub() Submission {
	return Submission{
		SignedBy:   "Alex Chen",
		LoginEmail: "login@example.com",
		Disclosures: []Disclosure{
			{ID: "termsOfUse", Accepted: true}, {ID: "customerAgreement", Accepted: true}, {ID: "marketDataAgreement", Accepted: true},
			{ID: "privacyPolicy", Accepted: true}, {ID: "dataSharing", Accepted: true}, {ID: "rule14b", Accepted: false},
			{ID: "p_terms", Source: "PARTNER", Accepted: true},
		},
	}
}

func docsByType(t *testing.T, docs ...[]Document) map[string]map[string]any {
	t.Helper()
	out := map[string]map[string]any{}
	for _, list := range docs {
		for _, d := range list {
			if _, dup := out[d.Type]; dup {
				t.Fatalf("重复的 document: %s", d.Type)
			}
			out[d.Type] = d.Data
		}
	}
	return out
}

func TestBuildSplitsCoreAndRest(t *testing.T) {
	core, rest, err := Build(usData(), sub())
	if err != nil {
		t.Fatal(err)
	}
	var coreTypes, restTypes []string
	for _, d := range core {
		coreTypes = append(coreTypes, d.Type)
	}
	for _, d := range rest {
		restTypes = append(restTypes, d.Type)
	}
	if !reflect.DeepEqual(coreTypes, CoreTypes) {
		t.Fatalf("POST /users 应只含四类核心 documents，实际 %v", coreTypes)
	}
	want := []string{DocEmploymentInfo, DocInvestorProfile, DocComplianceAML, DocDisclosures, DocTaxInfo}
	if !reflect.DeepEqual(restTypes, want) {
		t.Fatalf("PATCH documents = %v，期望 %v", restTypes, want)
	}
}

func TestBuildFieldMapping(t *testing.T) {
	type check struct {
		doc, field string
		want       any
	}
	cases := []struct {
		name   string
		data   func() Data
		sub    func() Submission
		checks []check
		absent []check // 不应出现的字段（want 忽略）
	}{
		{
			name: "美国纳税人（SSN）",
			data: usData, sub: sub,
			checks: []check{
				{DocBasicInfo, "firstName", "Alex"}, {DocBasicInfo, "lastName", "Chen"},
				{DocBasicInfo, "country", "USA"}, {DocBasicInfo, "phone", "+14155550142"},
				{DocBasicInfo, "emailAddress", "alex@example.com"}, {DocBasicInfo, "language", "zh_CN"},
				{DocIdentification, "value", "123456789"}, {DocIdentification, "type", "SSN"}, {DocIdentification, "citizenship", "USA"},
				{DocPersonalInfo, "birthDay", 7}, {DocPersonalInfo, "birthMonth", 3}, {DocPersonalInfo, "birthYear", 1990},
				{DocPersonalInfo, "politicallyExposedNames", ""}, {DocPersonalInfo, "irsBackupWithholdings", false},
				{DocAddressInfo, "street1", "200 Market Street"}, {DocAddressInfo, "street2", "Apt 5B"},
				{DocAddressInfo, "city", "San Francisco"}, {DocAddressInfo, "province", "CA"},
				{DocAddressInfo, "postalCode", "94105"}, {DocAddressInfo, "country", "USA"},
				{DocEmploymentInfo, "status", "EMPLOYED"}, {DocEmploymentInfo, "broker", false},
				{DocEmploymentInfo, "directorOf", ""}, {DocEmploymentInfo, "company", "Example Corp"},
				{DocEmploymentInfo, "type", "PROFESSIONAL"}, {DocEmploymentInfo, "position", "ENGINEER"},
				{DocInvestorProfile, "investmentExperience", "YRS_3_5"}, {DocInvestorProfile, "annualIncome", 150000},
				{DocInvestorProfile, "networthTotal", 350000}, {DocInvestorProfile, "networthLiquid", 125000},
				{DocInvestorProfile, "riskTolerance", "MODERATE"}, {DocInvestorProfile, "investmentObjectives", "GROWTH"},
				{DocComplianceAML, "fundingSources", []string{"EMP", "SAVINGS"}},
				{DocDisclosures, "termsOfUse", true}, {DocDisclosures, "customerAgreement", true},
				{DocDisclosures, "marketDataAgreement", true}, {DocDisclosures, "privacyPolicy", true},
				{DocDisclosures, "dataSharing", true}, {DocDisclosures, "rule14b", false}, {DocDisclosures, "signedBy", "Alex Chen"},
				{DocTaxInfo, "usTaxpayer", true}, {DocTaxInfo, "taxTreatyWithUS", false},
			},
			absent: []check{{DocIdentification, "issuingCountry", nil}, {DocDisclosures, "extendedHoursAgreement", nil}, {DocDisclosures, "p_terms", nil}},
		},
		{
			name: "非美国纳税人（外国税号）",
			data: intlData, sub: sub,
			checks: []check{
				{DocIdentification, "type", "FTIN"}, {DocIdentification, "value", "S1234567D"},
				{DocIdentification, "citizenship", "SGP"}, {DocIdentification, "issuingCountry", "SGP"},
				{DocBasicInfo, "country", "SGP"}, {DocAddressInfo, "country", "SGP"},
				{DocTaxInfo, "usTaxpayer", false}, {DocTaxInfo, "taxTreatyWithUS", true},
			},
			absent: []check{{DocPersonalInfo, "irsBackupWithholdings", nil}, {DocAddressInfo, "street2", nil}},
		},
		{
			name: "PEP、控制人、券商关联",
			data: func() Data {
				d := usData()
				d.IsPEP, d.PEPName = ptr(true), "Jordan Lee"
				d.IsControlPerson, d.ControlCompanyName, d.ControlCompanySymbol = ptr(true), "Acme Inc", "acme"
				d.IsAffiliatedBD, d.AffiliatedFirmName = ptr(true), "Example Securities"
				return d
			},
			sub: sub,
			checks: []check{
				{DocPersonalInfo, "politicallyExposedNames", "Jordan Lee"},
				{DocEmploymentInfo, "directorOf", "Acme Inc (ACME)"},
				{DocEmploymentInfo, "broker", true},
			},
		},
		{
			name:   "无业：不发送雇主与职位",
			data:   func() Data { d := usData(); d.EmploymentStatus = "UNEMPLOYED"; return d },
			sub:    sub,
			checks: []check{{DocEmploymentInfo, "status", "UNEMPLOYED"}},
			absent: []check{{DocEmploymentInfo, "company", nil}, {DocEmploymentInfo, "position", nil}, {DocEmploymentInfo, "type", nil}},
		},
		{
			name: "联系邮箱为空时用登录邮箱；同意盘前盘后协议",
			data: func() Data { d := usData(); d.ContactEmail = " "; return d },
			sub: func() Submission {
				s := sub()
				s.Disclosures = append(s.Disclosures, Disclosure{ID: "extendedHoursAgreement", Accepted: true}, Disclosure{ID: "rule14b", Accepted: true})
				return s
			},
			checks: []check{
				{DocBasicInfo, "emailAddress", "login@example.com"},
				{DocDisclosures, "extendedHoursAgreement", true},
				{DocDisclosures, "rule14b", true},
			},
		},
		{
			name:   "未知语言不发送（language 为可选）",
			data:   func() Data { d := usData(); d.Language = ""; return d },
			sub:    sub,
			absent: []check{{DocBasicInfo, "language", nil}},
		},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			core, rest, err := Build(tc.data(), tc.sub())
			if err != nil {
				t.Fatal(err)
			}
			got := docsByType(t, core, rest)
			for _, c := range tc.checks {
				v, ok := got[c.doc][c.field]
				if !ok {
					t.Errorf("%s.%s 缺失", c.doc, c.field)
					continue
				}
				if !reflect.DeepEqual(v, c.want) {
					t.Errorf("%s.%s = %#v，期望 %#v", c.doc, c.field, v, c.want)
				}
			}
			for _, c := range tc.absent {
				if _, ok := got[c.doc][c.field]; ok {
					t.Errorf("%s.%s 不应发送", c.doc, c.field)
				}
			}
		})
	}
}

func TestBuildMappingErrors(t *testing.T) {
	cases := []struct {
		name   string
		mutate func(*Data)
		want   []string
	}{
		{"国籍不在对照表", func(d *Data) { d.Citizenship = "FR" }, []string{"citizenship"}},
		{"出生日期格式错误", func(d *Data) { d.DateOfBirth = "07/03/1990" }, []string{"dateOfBirth"}},
		{"枚举取值未知", func(d *Data) { d.RiskTolerance = "EXTREME"; d.AnnualIncomeRange = "lots" }, []string{"annualIncomeRange", "riskTolerance"}},
		{"缺少居住地址", func(d *Data) { d.ResidentialAddress = nil }, []string{"residentialAddress.country"}},
		{"行业未知", func(d *Data) { d.Industry = "SPACE" }, []string{"industry"}},
		{"职位未知", func(d *Data) { d.Position = "OTHER" }, []string{"position"}},
		{"在职缺行业", func(d *Data) { d.Industry = "" }, []string{"industry"}},
		{"资金来源未知", func(d *Data) { d.FundingSources = []string{"LOTTERY"} }, []string{"fundingSources"}},
		{"美国州无法识别（沙盒 E032）", func(d *Data) { d.ResidentialAddress.State = "Kalifornia" }, []string{"residentialAddress.state"}},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			d := usData()
			tc.mutate(&d)
			_, _, err := Build(d, sub())
			me, ok := err.(*MappingError)
			if !ok {
				t.Fatalf("应返回 *MappingError，实际 %v", err)
			}
			if !reflect.DeepEqual(me.Fields, tc.want) {
				t.Fatalf("字段 = %v，期望 %v", me.Fields, tc.want)
			}
			// 错误信息只含字段名，不含用户填写的值
			for _, leak := range []string{"FR", "07/03/1990", "EXTREME", "lots", "LOTTERY", "123-45-6789"} {
				if strings.Contains(me.Error(), leak) {
					t.Fatalf("错误信息泄露取值 %q: %s", leak, me.Error())
				}
			}
		})
	}
}

func TestNormalizeUSState(t *testing.T) {
	for _, tc := range []struct{ in, want string }{
		{"CA", "CA"}, {" ca ", "CA"}, {"C.A.", "CA"}, {"California", "CA"}, {"new york", "NY"}, {"NEW-YORK", "NY"},
		{"District of Columbia", "DC"}, {"Washington, D.C.", "DC"}, {"pr", "PR"},
		{"Califrnia", ""}, {"XX", ""}, {"", ""},
	} {
		got, ok := NormalizeUSState(tc.in)
		if got != tc.want || ok != (tc.want != "") {
			t.Errorf("NormalizeUSState(%q) = %q %v，期望 %q", tc.in, got, ok, tc.want)
		}
	}
	// 全称在映射时转为代码
	d := usData()
	d.ResidentialAddress.State = "california"
	core, _, err := Build(d, sub())
	if err != nil {
		t.Fatal(err)
	}
	for _, doc := range core {
		if doc.Type == DocAddressInfo && doc.Data["province"] != "CA" {
			t.Fatalf("province = %v，期望 CA", doc.Data["province"])
		}
	}
}

func TestNormalizers(t *testing.T) {
	cases := []struct{ name, got, want string }{
		{"SSN 去连字符", NormalizeTIN("SSN", "123-45-6789"), "123456789"},
		{"ITIN 去空格", NormalizeTIN("ITIN", "912 34 5678"), "912345678"},
		{"外国税号保留字母", NormalizeTIN("FOREIGN_TIN", " AB 12 cd "), "AB12cd"},
		{"电话保留 +", NormalizePhone("+1 (415) 555-0142"), "+14155550142"},
		{"电话无 +", NormalizePhone("415.555.0142"), "4155550142"},
	}
	for _, tc := range cases {
		if tc.got != tc.want {
			t.Errorf("%s: %q，期望 %q", tc.name, tc.got, tc.want)
		}
	}
}

// 每个 App 合法取值都必须能映射（防止对照表与校验列表不一致）。
func TestAllowedValuesAllMap(t *testing.T) {
	for _, field := range []string{"industry", "position", "citizenship", "tinType", "employmentStatus", "investmentExperience", "investmentObjective", "riskTolerance", "fundingSources", "language", "annualIncomeRange", "netWorthRange"} {
		vals := Allowed(field)
		if len(vals) == 0 {
			t.Fatalf("%s 没有合法取值", field)
		}
		for _, v := range vals {
			d := usData()
			switch field {
			case "industry":
				d.Industry = v
			case "position":
				d.Position = v
			case "citizenship":
				d.Citizenship = v
			case "tinType":
				d.TINType = v
			case "employmentStatus":
				d.EmploymentStatus = v
				if v != "EMPLOYED" && v != "SELF_EMPLOYED" {
					d.Industry, d.Position = "", ""
				}
			case "investmentExperience":
				d.InvestmentExperience = v
			case "investmentObjective":
				d.InvestmentObjective = v
			case "riskTolerance":
				d.RiskTolerance = v
			case "fundingSources":
				d.FundingSources = []string{v}
			case "language":
				d.Language = v
			case "annualIncomeRange":
				d.AnnualIncomeRange = v
			case "netWorthRange":
				d.NetWorthRange = v
			}
			if _, _, err := Build(d, sub()); err != nil {
				t.Errorf("%s=%s 无法映射: %v", field, v, err)
			}
		}
	}
	if Allowed("unknown") != nil {
		t.Fatal("未知字段应返回 nil")
	}
}

// Data 的 JSON 字段名必须与 openapi.yaml ApplicationData 完全一致（api-spec.md 第 10 节：字段名以 openapi 为准）。
func TestDataMatchesOpenAPI(t *testing.T) {
	var doc struct {
		Components struct {
			Schemas map[string]struct {
				Properties map[string]any `yaml:"properties"`
			} `yaml:"schemas"`
		} `yaml:"components"`
	}
	if err := yaml.Unmarshal(api.OpenAPI, &doc); err != nil {
		t.Fatal(err)
	}
	spec := keys(doc.Components.Schemas["ApplicationData"].Properties)
	var mine []string
	rt := reflect.TypeOf(Data{})
	for i := 0; i < rt.NumField(); i++ {
		mine = append(mine, strings.Split(rt.Field(i).Tag.Get("json"), ",")[0])
	}
	sort.Strings(mine)
	if !reflect.DeepEqual(mine, spec) {
		t.Fatalf("Data 字段与 openapi ApplicationData 不一致\nData:    %v\nopenapi: %v", mine, spec)
	}
	addr := keys(doc.Components.Schemas["ApplicationData"].Properties["residentialAddress"].(map[string]any)["properties"].(map[string]any))
	var mineAddr []string
	at := reflect.TypeOf(Address{})
	for i := 0; i < at.NumField(); i++ {
		mineAddr = append(mineAddr, strings.Split(at.Field(i).Tag.Get("json"), ",")[0])
	}
	sort.Strings(mineAddr)
	if !reflect.DeepEqual(mineAddr, addr) {
		t.Fatalf("Address 字段与 openapi 不一致: %v vs %v", mineAddr, addr)
	}
}

func keys[V any](m map[string]V) []string {
	out := make([]string, 0, len(m))
	for k := range m {
		out = append(out, k)
	}
	sort.Strings(out)
	return out
}

func TestRequestBodies(t *testing.T) {
	core, rest, _ := Build(usData(), sub())
	b, _ := json.Marshal(CreateUserBody("u_test", "p_test", core))
	var m map[string]any
	_ = json.Unmarshal(b, &m)
	if m["userType"] != UserType || m["username"] != "u_test" || len(m["documents"].([]any)) != 4 {
		t.Fatalf("POST /users 请求体不正确: %v", m)
	}
	b, _ = json.Marshal(PatchUserBody(rest))
	_ = json.Unmarshal(b, &m)
	if len(m["documents"].([]any)) != 5 {
		t.Fatalf("PATCH 请求体不正确")
	}
	// Document.String 不打印 PII
	if s := core[1].String(); strings.Contains(s, "123456789") {
		t.Fatalf("String() 泄露 PII: %s", s)
	}
}

// 审计 DOC-P1-6/P1-7：Q-DW-9（"不适用"取值）与 Q-DW-10（ITIN 对应类型）走配置，不写死。
func TestConfigureQDWSwitches(t *testing.T) {
	t.Cleanup(func() { Configure(Options{NoneValue: "", ITINTaxType: "SSN", NINTaxType: "OTHER"}) })
	Configure(Options{NoneValue: "NONE", ITINTaxType: "OTHER", NINTaxType: "PASSPORT"})
	d := usData()
	d.TINType = "ITIN"
	d.TIN = "912-70-1234"
	core, rest, err := Build(d, sub())
	if err != nil {
		t.Fatal(err)
	}
	got := docsByType(t, core, rest)
	if v := got[DocPersonalInfo]["politicallyExposedNames"]; v != "NONE" {
		t.Errorf("politicallyExposedNames = %#v，期望配置值 NONE", v)
	}
	if v := got[DocEmploymentInfo]["directorOf"]; v != "NONE" {
		t.Errorf("directorOf = %#v，期望配置值 NONE", v)
	}
	if v := got[DocIdentification]["type"]; v != "OTHER" {
		t.Errorf("ITIN 映射 = %#v，期望配置值 OTHER", v)
	}
	if tinTypeDW["NIN"] != "PASSPORT" {
		t.Errorf("NIN 映射未生效：%s", tinTypeDW["NIN"])
	}
}
