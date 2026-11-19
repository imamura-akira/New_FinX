/// 开户表单选项（开户与 KYC 模块一律英文，标签取自原型 prototype/js/pages/onboarding.js）。
/// 取值为接口取值（openapi ApplicationData），后端按 dwmapper 映射为 DW 取值。
typedef Option = (String value, String label);

String labelOf(List<Option> options, String? value) {
  for (final (v, l) in options) {
    if (v == value) return l;
  }
  return value == null || value.isEmpty ? '—' : value;
}

const countries = <Option>[
  ('US', 'United States'),
  ('CN', 'China'),
  ('HK', 'Hong Kong'),
  ('TW', 'Taiwan'),
  ('SG', 'Singapore'),
  ('GB', 'United Kingdom'),
  ('CA', 'Canada'),
  ('AU', 'Australia'),
  ('JP', 'Japan'),
];

/// 文件与通知语言：标签为各语言的自称（与原型一致）。
const languages = <Option>[('zh_CN', '简体中文'), ('zh_TW', '繁體中文'), ('en_US', 'English')];

const incomeRanges = <Option>[
  ('<25k', 'Under \$25,000'),
  ('25k-50k', '\$25,000 – \$50,000'),
  ('50k-100k', '\$50,000 – \$100,000'),
  ('100k-200k', '\$100,000 – \$200,000'),
  ('>200k', 'Over \$200,000'),
];

const netWorthRanges = <Option>[
  ('<50k', 'Under \$50,000'),
  ('50k-200k', '\$50,000 – \$200,000'),
  ('200k-500k', '\$200,000 – \$500,000'),
  ('500k-1m', '\$500,000 – \$1,000,000'),
  ('>1m', 'Over \$1,000,000'),
];

const employmentStatuses = <Option>[
  ('EMPLOYED', 'Employed'),
  ('SELF_EMPLOYED', 'Self-employed'),
  ('UNEMPLOYED', 'Unemployed'),
  ('RETIRED', 'Retired'),
  ('STUDENT', 'Student'),
];

bool isEmployed(String? status) => status == 'EMPLOYED' || status == 'SELF_EMPLOYED';

const experiences = <Option>[('NONE', 'None'), ('1-2', '1–2 years'), ('3-5', '3–5 years'), ('5+', '5+ years')];

const objectives = <Option>[('GROWTH', 'Growth'), ('INCOME', 'Income'), ('PRESERVE', 'Capital preservation'), ('SPEC', 'Speculation')];

const riskLevels = <Option>[('LOW', 'Low'), ('MED', 'Medium'), ('HIGH', 'High')];

const idTypes = <Option>[
  ('PASSPORT', 'Passport'),
  ('NATIONAL_ID_CARD', 'National ID card'),
  ('DRIVER_LICENSE', "Driver's license"),
  ('RESIDENCE_PERMIT', 'Residence permit'),
];

/// 资金来源：与 DW 取值一一对应（2026-11-19 用户决定，ui-signoff 第 3 节登记）。
const fundingSources = <Option>[
  ('EMP', 'Employment income'),
  ('SAVINGS', 'Savings'),
  ('INVESTMENT', 'Investment returns'),
  ('GIFT', 'Gift / Inheritance'),
  ('RETIRE', 'Retirement'),
  ('FAMILY', 'Family support'),
  ('SALE', 'Sale of assets'),
  ('RENT', 'Rental income'),
];

List<Option> tinTypesFor(String? usTaxPayer) => usTaxPayer == 'YES'
    ? const [('SSN', 'Social Security Number (SSN)'), ('ITIN', 'Individual Taxpayer ID (ITIN)')]
    : const [('FOREIGN_TIN', 'National tax ID (TIN)'), ('NIN', 'National ID number (NIN)')];

/// 所属行业（DW EMPLOYMENT_INFO.type，pages.md 3.1.6）。
const industries = <Option>[
  ('AGRICULTURE', 'Agriculture, forestry & fishing'),
  ('MINING', 'Mining'),
  ('UTILITIES', 'Utilities'),
  ('CONSTRUCTION', 'Construction'),
  ('MANUFACTURING', 'Manufacturing'),
  ('WHOLESALE', 'Wholesale trade'),
  ('RETAIL', 'Retail trade'),
  ('TRANSPORT', 'Transportation & warehousing'),
  ('INFORMATION', 'Information & media'),
  ('FINANCE', 'Finance & insurance'),
  ('REAL_ESTATE', 'Real estate & leasing'),
  ('PROFESSIONAL', 'Professional, scientific & technical services'),
  ('MANAGEMENT', 'Management of companies'),
  ('EDUCATION', 'Education'),
  ('HEALTH', 'Health care & social assistance'),
  ('ART', 'Arts, entertainment & recreation'),
  ('FOOD', 'Accommodation & food services'),
  ('PUBLIC', 'Public administration'),
  ('WASTE', 'Waste management & remediation'),
];

/// 职位（DW EMPLOYMENT_INFO.position，89 项，pages.md 3.1.6）。
const positions = <Option>[
  ('ACCOUNTANT', 'Accountant / CPA / Bookkeeper'),
  ('ACTUARY', 'Actuary'),
  ('ADJUSTER', 'Claims adjuster'),
  ('ADMINISTRATOR', 'Administrator'),
  ('ADVERTISER', 'Advertising / marketing'),
  ('AGENT', 'Agent'),
  ('ATC', 'Air traffic controller'),
  ('AMBASSADOR', 'Ambassador / diplomat'),
  ('ANALYST', 'Analyst'),
  ('APPRAISER', 'Appraiser'),
  ('ARCHITECT', 'Architect'),
  ('ARTIST', 'Artist'),
  ('ASSISTANT', 'Assistant'),
  ('ATHLETE', 'Athlete'),
  ('ATTENDANT', 'Attendant'),
  ('ATTORNEY', 'Attorney'),
  ('AUCTIONEER', 'Auctioneer'),
  ('AUDITOR', 'Auditor'),
  ('BARBER', 'Barber / hairstylist'),
  ('BROKER', 'Broker'),
  ('BUSINESS_EXEC', 'Business executive'),
  ('BUSINESS_OWNER', 'Business owner'),
  ('CAREGIVER', 'Caregiver'),
  ('CARPENTER', 'Carpenter'),
  ('CASHIER', 'Cashier'),
  ('CHEF', 'Chef / cook'),
  ('CHIROPRACTOR', 'Chiropractor'),
  ('CIVIL', 'Civil servant'),
  ('CLERGY', 'Clergy'),
  ('CLERK', 'Clerk'),
  ('COMPLIANCE', 'Compliance officer'),
  ('CONSULTANT', 'Consultant'),
  ('CONTRACTOR', 'Contractor'),
  ('COUNSELOR', 'Counselor'),
  ('CUSTOMER_SERVICE', 'Customer service'),
  ('DEALER', 'Dealer'),
  ('DEVELOPER', 'Developer'),
  ('DISTRIBUTOR', 'Distributor'),
  ('DOCTOR', 'Doctor / physician'),
  ('DRIVER', 'Driver'),
  ('ENGINEER', 'Engineer'),
  ('EXAMINER', 'Examiner / inspector'),
  ('EXTERMINATOR', 'Exterminator'),
  ('FACTORY', 'Factory worker'),
  ('FARMER', 'Farmer'),
  ('FINANCIAL', 'Financial professional'),
  ('FISHERMAN', 'Fisherman'),
  ('FLIGHT', 'Flight crew'),
  ('HR', 'Human resources'),
  ('IMPEX', 'Import / export'),
  ('INSPECTOR', 'Inspector'),
  ('INTERN', 'Intern'),
  ('INVESTMENT', 'Investment professional'),
  ('INVESTOR', 'Investor'),
  ('IT', 'IT professional'),
  ('JANITOR', 'Janitor'),
  ('JEWELER', 'Jeweler'),
  ('LABORER', 'Laborer'),
  ('LANDSCAPER', 'Landscaper'),
  ('LENDING', 'Lending professional'),
  ('MANAGER', 'Manager'),
  ('MECHANIC', 'Mechanic'),
  ('MILITARY', 'Military'),
  ('MORTICIAN', 'Mortician'),
  ('NURSE', 'Nurse'),
  ('NUTRITIONIST', 'Nutritionist'),
  ('OFFICE', 'Office worker'),
  ('PHARMACIST', 'Pharmacist'),
  ('PHYSICAL', 'Physical therapist'),
  ('PILOT', 'Pilot'),
  ('POLICE', 'Police officer'),
  ('POLITICIAN', 'Politician'),
  ('PM', 'Project manager'),
  ('REP', 'Sales representative'),
  ('RESEARCHER', 'Researcher'),
  ('SAILOR', 'Sailor'),
  ('SALES', 'Sales'),
  ('SCIENTIST', 'Scientist'),
  ('SEAMSTRESS', 'Tailor / seamstress'),
  ('SECURITY', 'Security officer'),
  ('SOCIAL', 'Social worker'),
  ('TEACHER', 'Teacher'),
  ('TECHNICIAN', 'Technician'),
  ('TELLER', 'Bank teller'),
  ('TRADESPERSON', 'Tradesperson'),
  ('TRAINER', 'Trainer'),
  ('TRANSPORTER', 'Transporter'),
  ('UNDERWRITER', 'Underwriter'),
  ('WRITER', 'Writer / editor'),
];

/// P-05 披露（DW DISCLOSURES 字段与平台条款；标题取自原型）。
const dwDisclosures = <Option>[
  ('termsOfUse', 'Terms of Use'),
  ('customerAgreement', 'Customer Account Agreement'),
  ('marketDataAgreement', 'Market Data Agreement'),
  ('privacyPolicy', 'Privacy Policy'),
  ('dataSharing', 'Data Sharing Consent'),
];

const partnerDisclosures = <Option>[
  ('p_terms', 'FinX Terms of Service'),
  ('p_privacy', 'FinX Privacy Policy'),
  ('p_risk', 'FinX Investment Risk Disclosure'),
];

const dwDisclosureUrl = 'https://apps.drivewealth.com/disclosures'; // 同原型 DW_DISCLOSURE_URL
