# Questions for DriveWealth Integration Team（Q-DW 问题单）

> 发送对象：DW 集成对接人（UAT / sandbox 阶段）。
> 与 `pages.md` 第 5.1 节对应。**Q-DW-1、Q-DW-2 是沙盒接入的前置条件**，请优先回复。
> 本文件不含任何凭据或真实账户编号。

---

## Blocking (needed before sandbox integration)

**Q-DW-1 — KYC model**
Which KYC model is configured for our UAT / production account: **Do KYC**, **No KYC**, or **Verify KYC**?
Our design assumes Do KYC (DriveWealth performs screening and `kyc.status.name` progresses through intermediate states). If our account is No KYC / Verify KYC, we would need to perform KYC/CIP ourselves and submit `KYC_VERIFICATION_INFO`.
（中文：我方账户的 KYC 模式？设计按 Do KYC 假设，若非 Do KYC 需重写 3.2.1 / P-04 / P-34–P-36。）

**Q-DW-2 — Bank account linking method**
For ACH funding, should we link bank accounts by direct entry (`POST /back-office/bank-accounts` with `bankAccountNumber` / `bankRoutingNumber`), or via the Plaid integration (processor token)?
If direct entry: how do we satisfy the requirement that the bank account owner name matches the account holder (third-party funding control)?
If Plaid: please share the processor-token flow documentation for our setup.
（中文：绑卡走直接录入还是 Plaid？直接录入时户名一致性如何校验（PDF-3）？）

## High priority (can be answered during sandbox)

**Q-DW-3 — Single-call user creation**
Can `POST /users` include all documents in one call (EMPLOYMENT_INFO, INVESTOR_PROFILE_INFO, DISCLOSURES, TAX_INFO, COMPLIANCE_AML_INFO included), or must those be added via `PATCH /users/{userID}` after creation? We currently plan POST (4 core documents) + PATCH (the rest).

**Q-DW-4 — username / password**
Is it acceptable for our backend to generate and store the `username` / `password` values required by `POST /users` (never shown to the end user)? Any format requirements?

**Q-DW-5 — Triggering KYC outcomes in sandbox**
How can we trigger `KYC_INFO_REQUIRED`, `KYC_DOC_REQUIRED`, `KYC_MANUAL_REVIEW`, and `KYC_DENIED` in sandbox, so we can test our remediation screens? Are there magic values / test fixtures?

**Q-DW-6 — Fields**
a) Is `COMPLIANCE_AML_INFO` required for our program? What are the allowed `fundingSources` enum values?
b) Can an Apple private relay email be used as `BASIC_INFO.emailAddress`?

## Medium priority

**Q-DW-7 — riaID / riaProductID**
Our partner configuration sheet lists `riaID` and `riaProductID`, but the opening-accounts documentation only references `riaUserID` (RIA_MANAGED only). For SELF accounts in our first release, do we omit all RIA fields? Where (if anywhere) are `riaID` / `riaProductID` used?

**Q-DW-8 — Funding & accounts details**
a) Full combination matrix for `accountType` / `tradingType` / `accountManagementType` (incl. MARGIN, RIA_MANAGED).
b) Do we need the Master Trading / Cleanup corporate accounts for our (individual-accounts-only) first release?
c) Full enum for deposit `type` (docs show `ACH`, `CASH_PROMOTION`).
d) Request fields and status enum for `POST /funding/redemptions` (ACH and WIRE).
e) Configured values for our program: ACH buying-power timing (default: after settlement, typically 4–5 business days), ACH seasoning period (default 30 days — and does it start when funds clear?), applicability of the 5-business-day hold described at legal.drivewealth.com, deposit/withdrawal cutoff times, wire fees.

---

*Prepared 2026-11-19. Sources verified against developer.drivewealth.com (creating-a-user, opening-accounts, depositing-1, individual-funding), legal.drivewealth.com and info.drivewealth.com funding policies.*
