# DW 原始报文样本（dw-raw-samples.md）

> **DriveWealth UAT 沙盒环境实测报文，非生产数据。**
> 用途：向合作方 / 客户展示本 App 后端真实对接 DriveWealth 沙盒（App → 我方后端 → DW，App 不直连 DW）。

| 项 | 内容 |
|---|---|
| 环境 | DriveWealth UAT 沙盒（`bo-api.drivewealth.io/back-office`），本机后端 `DW_LOG_BODIES=true` |
| 采集时间 | 2026-11-20 05:50 UTC（美东 11-20 00:50，非工作时间）；窗口期后复查 2026-11-20 14:33 UTC（第 4 节） |
| 测试用户 | 虚构沙盒测试用户（`funded1@example.com`），已开户（LIVE / CASH / SELF），已绑定虚构银行账户 |
| 操作 | 在 App 后端发起一笔 **$10 ACH 入金**，随后查询资金汇总，后台对账任务每 10 秒查询入金状态 |
| 来源 | 后端日志中 `dwclient` 记录的请求体 / 响应体，未经手工改写 |

**脱敏规则**
- 原样保留：DW 的各类 id（入金 id、accountID、userID、bankAccountID、request id 等）、状态、金额、日期时间。
- 已打码：账户号码（`accountNo` / `account_number`，保留尾 4 位）、银行账号与路由号（保留尾 4 位）、姓名与邮箱（保留首字母）、DW 用户名。
- 请求头（含 Authorization、DW App Key）不写入日志，因此本文件不含任何凭据。
- 补充：银行户名 `accountHolderName` 在采集时未被日志脱敏覆盖，本文件中已打码（保留首字母）；日志脱敏规则已同步修正。
- 说明：DW 入金 id 的前缀由 DW 按账户号码生成（如 `FEYQ000001-…`），按"id 原样保留"的规则未改动；均为沙盒虚构账户。

---

## 1. 创建 ACH 入金：`POST /funding/deposits`

我方后端在用户确认入金后调用 DW 创建入金（附 Idempotency-Key 防重复提交）。DW 立即受理，返回入金 id 与初始状态 **17 Processing**（该状态不在 DW 文档枚举中，见 sandbox-log 2026-11-19）。

`POST /funding/deposits` · HTTP 200 · 2026-11-20T05:50:19.854623Z · DW request id `request_b17219d6-0e4a-4e98-b94a-4b7533143908_clm`

**请求体**

```json
{
  "accountNo": "******0001",
  "amount": 10,
  "bankAccountID": "bank_02797f3e-7f75-4cbf-b437-407b58c98cd9",
  "currency": "USD",
  "type": "ACH"
}
```

**DW 响应体**

```json
{
  "accountID": "0e05d5c1-b209-4237-a4a7-6296bc726534.1795093468784",
  "accountNo": "******0001",
  "account_number": "******0001",
  "amount": 10,
  "batch": true,
  "category": "DEPOSIT",
  "created": "2026-11-20T05:50:19.662Z",
  "currency": "USD",
  "id": "FEYQ000001-1795153819661-DOZDW",
  "source": {
    "brand": "ACH",
    "id": "ACH",
    "meta_info": "null|Demo Checking|****6789"
  },
  "status": {
    "id": 17,
    "message": "Processing",
    "updated": "2026-11-20T05:50:19.662Z"
  },
  "transactionCode": "RECEIPT_ACH_MT",
  "userID": "0e05d5c1-b209-4237-a4a7-6296bc726534",
  "wlpFinTranTypeID": "536c7cff-c7eb-472c-bb88-30f6a2169227"
}
```

---

## 2. 查询入金最终状态：`GET /funding/deposits/{id}`

后台对账任务按入金 id 查询状态。本次为美东非工作时间，DW 将入金推进到 **14 Approved** 后停在 **"Awaiting money movement window to open."**（等待资金划转窗口开放），资金尚未入账——原样入档，作为窗口期实证（sandbox-log 2026-11-20）。以下为采集期间最后一次查询的响应（共查询 8 次，内容一致）。

`GET /funding/deposits/FEYQ000001-1795153819661-DOZDW` · HTTP 200 · 2026-11-20T05:51:37.2199Z · DW request id `request_523e6c21-f43e-48a8-b788-8f43c3b0c7e3_clm`

**DW 响应体**

```json
{
  "accountDetails": {
    "accountID": "0e05d5c1-b209-4237-a4a7-6296bc726534.1795093468784",
    "accountManagementType": {
      "description": "Self Directed Account",
      "name": "SELF"
    },
    "accountNo": "******0001",
    "accountType": {
      "description": "Live Account",
      "name": "LIVE"
    }
  },
  "amount": 10,
  "bankAccountID": "bank_02797f3e-7f75-4cbf-b437-407b58c98cd9",
  "batch": true,
  "category": "DEPOSIT",
  "created": "2026-11-20T05:50:19.662Z",
  "currency": {
    "description": "US Dollar",
    "name": "USD",
    "symbol": "$"
  },
  "details": {
    "accountHolderName": "D***",
    "bankAccountNickname": "Demo Checking",
    "bankAccountNumber": "****6789",
    "bankAccountType": "CHECKING",
    "bankRoutingNumber": "****0021",
    "country": "USA"
  },
  "id": "FEYQ000001-1795153819661-DOZDW",
  "note": "null|Demo Checking|****6789",
  "otherDetails": "null|Demo Checking|****6789",
  "status": {
    "comment": "Payment successfully submitted. Moved to Approved",
    "id": 14,
    "message": "Approved",
    "updated": "2026-11-20T05:50:21.280Z"
  },
  "statusHistory": [
    {
      "comment": "New deposit request from the back-office",
      "created": "2026-11-20T05:50:19.658935597Z",
      "status": 0,
      "statusMessage": "Started",
      "updatedBy": "bo.finx.api"
    },
    {
      "comment": "Valid request. Auto-move to Pending",
      "created": "2026-11-20T05:50:19.658955127Z",
      "status": 1,
      "statusMessage": "Pending",
      "updatedBy": "SYSTEM"
    },
    {
      "comment": "Valid request. Auto-move to Processing",
      "created": "2026-11-20T05:50:19.658956951Z",
      "status": 17,
      "statusMessage": "Processing",
      "updatedBy": "SYSTEM"
    },
    {
      "comment": "Payment successfully submitted. Moved to Approved",
      "created": "2026-11-20T05:50:20.152776193Z",
      "status": 14,
      "statusMessage": "Approved",
      "updatedBy": "BO-API ACH deposit service"
    },
    {
      "comment": "Awaiting money movement window to open.",
      "created": "2026-11-20T05:50:21.280458839Z",
      "status": 14,
      "statusMessage": "Approved",
      "updatedBy": "SYSTEM"
    }
  ],
  "transactionCode": {
    "code": "RECEIPT_ACH_MT",
    "description": "Cash Receipt - ACH MT",
    "type": "CSR"
  },
  "userDetails": {
    "email": "s***@example.com",
    "firstName": "D***",
    "lastName": "T***",
    "parentIB": {
      "id": "be390250-511f-4143-89e2-fd0e502039f0",
      "name": "Golden State Capital Inc."
    },
    "userID": "0e05d5c1-b209-4237-a4a7-6296bc726534",
    "username": "[REDACTED]",
    "wlpID": "FINX"
  },
  "wlpFinTranTypeID": "536c7cff-c7eb-472c-bb88-30f6a2169227"
}
```

---

## 3. 入金后的资金汇总：`GET /accounts/{accountID}/summary/money`

入金提交后，App 资产页通过我方 `GET /account/money` 触发后端查询 DW 资金汇总。由于本笔 $10 仍在等待资金划转窗口，`cashBalance` 仍为此前入金的 $1,000（尚未计入 $10）；该 $1,000 的购买力与可提现在 DW 返回的可用日（2026-11-23）之前为 0（`pendingDepositsAmountNotAvailable` / `amountWithheldFromRedemptions` 为 1000）。

`GET /accounts/0e05d5c1-b209-4237-a4a7-6296bc726534.1795093468784/summary/money` · HTTP 200 · 2026-11-20T05:50:23.782921Z · DW request id `request_b974ad41-c2e6-48a7-aaa9-6b4e2151e6ba_clm`

**DW 响应体**

```json
{
  "accountID": "0e05d5c1-b209-4237-a4a7-6296bc726534.1795093468784",
  "accountNo": "******0001",
  "cash": {
    "cashAvailableForTrade": 0,
    "cashAvailableForTradeNonMarginable": 0,
    "cashAvailableForWithdrawal": 0,
    "cashBalance": 1000,
    "cashPendingSettlement": 0,
    "cashSettlement": [
      {
        "cash": 0,
        "utcTime": "2026-11-20T14:30:00.001Z"
      }
    ],
    "noBuyingPowerReason": null,
    "pendingPaymentsAmount": 0
  },
  "payments": {
    "buyingPower": {
      "pendingDepositsAmountAvailable": -1000,
      "pendingDepositsAmountNotAvailable": 1000
    },
    "redemptions": {
      "amountWithheldFromRedemptions": 1000
    }
  },
  "tradingType": "CASH",
  "updated": "2026-11-20T05:50:23.625Z"
}
```

---

## 4. 窗口期后复查（2026-11-20 美东 09:31 / 北京 22:31）

同一笔 $10 ACH 入金在资金划转窗口开放后的状态。**DW 于 2026-11-20 09:01:04 UTC（美东 04:01）开放窗口**（状态历史 "MMW Open. Moving to Successful"），入金由 14 Approved 推进到 **2 Successful**，现金入账；同时 DW 记录"购买力与可提现暂扣至 2026-11-23"（`seasoningDetails.statusMessage = AWAITING_BUYING_POWER`）。采集方式：本机临时后端（`DW_LOG_BODIES=true`）查询资金汇总；入金详情因本地记录已是 SUCCESSFUL、对账任务不再查询，改用一次性临时命令按入金 id 查询（同一 dwclient，日志脱敏规则相同，命令未入库）。

`GET /funding/deposits/FEYQ000001-1795153819661-DOZDW` · HTTP 200 · 2026-11-20T22:34:06.312456+08:00 · DW request id `request_3ebe0af4-5882-44fb-9f11-319ba8f1d3c6_clm`

**DW 响应体**

```json
{
  "accountDetails": {
    "accountID": "0e05d5c1-b209-4237-a4a7-6296bc726534.1795093468784",
    "accountManagementType": {
      "description": "Self Directed Account",
      "name": "SELF"
    },
    "accountNo": "******0001",
    "accountType": {
      "description": "Live Account",
      "name": "LIVE"
    }
  },
  "amount": 10,
  "bankAccountID": "bank_02797f3e-7f75-4cbf-b437-407b58c98cd9",
  "batch": true,
  "category": "DEPOSIT",
  "created": "2026-11-20T05:50:19.662Z",
  "currency": {
    "description": "US Dollar",
    "name": "USD",
    "symbol": "$"
  },
  "details": {
    "accountHolderName": "D***",
    "bankAccountNickname": "Demo Checking",
    "bankAccountNumber": "****6789",
    "bankAccountType": "CHECKING",
    "bankRoutingNumber": "****0021",
    "country": "USA"
  },
  "finTranRef": "NK.481ba7a4-e980-492e-963c-00b1bef59e22",
  "id": "FEYQ000001-1795153819661-DOZDW",
  "note": "null|Demo Checking|****6789",
  "otherDetails": "null|Demo Checking|****6789",
  "seasoningDetails": {
    "depositBuyingPowerHoldExpires": "2026-11-23T00:00:00Z",
    "seasoningPeriodExpires": "2026-11-23T00:00:00Z",
    "status": 6,
    "statusMessage": "AWAITING_BUYING_POWER",
    "updated": "2026-11-20T09:01:04.909Z"
  },
  "status": {
    "comment": "MMW Open. Moving to Successful",
    "id": 2,
    "message": "Successful",
    "updated": "2026-11-20T09:01:04.904Z"
  },
  "statusHistory": [
    {
      "comment": "New deposit request from the back-office",
      "created": "2026-11-20T05:50:19.658935597Z",
      "status": 0,
      "statusMessage": "Started",
      "updatedBy": "bo.finx.api"
    },
    {
      "comment": "Valid request. Auto-move to Pending",
      "created": "2026-11-20T05:50:19.658955127Z",
      "status": 1,
      "statusMessage": "Pending",
      "updatedBy": "SYSTEM"
    },
    {
      "comment": "Valid request. Auto-move to Processing",
      "created": "2026-11-20T05:50:19.658956951Z",
      "status": 17,
      "statusMessage": "Processing",
      "updatedBy": "SYSTEM"
    },
    {
      "comment": "Payment successfully submitted. Moved to Approved",
      "created": "2026-11-20T05:50:20.152776193Z",
      "status": 14,
      "statusMessage": "Approved",
      "updatedBy": "BO-API ACH deposit service"
    },
    {
      "comment": "Awaiting money movement window to open.",
      "created": "2026-11-20T05:50:21.280458839Z",
      "status": 14,
      "statusMessage": "Approved",
      "updatedBy": "SYSTEM"
    },
    {
      "comment": "MMW Open. Moving to Successful",
      "created": "2026-11-20T09:01:04.896531347Z",
      "status": 2,
      "statusMessage": "Successful",
      "updatedBy": "SYSTEM"
    },
    {
      "comment": "Buying power withheld until 2026-11-23. Withdrawal power withheld until 2026-11-23",
      "created": "2026-11-20T09:01:04.904846203Z",
      "status": 2,
      "statusMessage": "Successful",
      "updatedBy": "SYSTEM"
    }
  ],
  "transactionCode": {
    "code": "RECEIPT_ACH_MT",
    "description": "Cash Receipt - ACH MT",
    "type": "CSR"
  },
  "userDetails": {
    "email": "s***@example.com",
    "firstName": "D***",
    "lastName": "T***",
    "parentIB": {
      "id": "be390250-511f-4143-89e2-fd0e502039f0",
      "name": "Golden State Capital Inc."
    },
    "userID": "0e05d5c1-b209-4237-a4a7-6296bc726534",
    "username": "[REDACTED]",
    "wlpID": "FINX"
  },
  "wlpFinTranTypeID": "536c7cff-c7eb-472c-bb88-30f6a2169227"
}
```

`GET /accounts/{accountID}/summary/money` · HTTP 200 · 2026-11-20T14:33:19.718034Z · DW request id `request_3c9c2235-d279-4a85-ab77-3140560d69af_clm`

`cashBalance` 由 1,000 变为 **1,010**（$10 已入账）；购买力与可提现仍为 0，`pendingDepositsAmountNotAvailable` / `amountWithheldFromRedemptions` 均为 1,010，DW 下一结算时点 `cashSettlement.utcTime` 为 2026-11-23T14:30Z——与入金详情中的 2026-11-23 一致。

**DW 响应体**

```json
{
  "accountID": "0e05d5c1-b209-4237-a4a7-6296bc726534.1795093468784",
  "accountNo": "******0001",
  "cash": {
    "cashAvailableForTrade": 0,
    "cashAvailableForTradeNonMarginable": 0,
    "cashAvailableForWithdrawal": 0,
    "cashBalance": 1010,
    "cashPendingSettlement": 0,
    "cashSettlement": [
      {
        "cash": 0,
        "utcTime": "2026-11-23T14:30:00.001Z"
      }
    ],
    "noBuyingPowerReason": null,
    "pendingPaymentsAmount": 0
  },
  "payments": {
    "buyingPower": {
      "pendingDepositsAmountAvailable": -1010,
      "pendingDepositsAmountNotAvailable": 1010
    },
    "redemptions": {
      "amountWithheldFromRedemptions": 1010
    }
  },
  "tradingType": "CASH",
  "updated": "2026-11-20T14:33:19.507Z"
}
```

我方接口对应：`GET /api/v1/funding/transfers` 显示该笔为"已完成"（SUCCESSFUL），购买力可用日与可提现日均为 2026-11-23；`GET /api/v1/account/money` 显示现金 $1,010、购买力 $0、可提现 $0、在途入金 $1,010、观察期内 $1,010。

---

### 我方接口对应关系

| DW 报文 | 我方接口（api-spec.md） | App 页面 |
|---|---|---|
| `POST /funding/deposits` | `POST /api/v1/funding/deposits` | P-13 入金确认 → 结果页 |
| `GET /funding/deposits/{id}` | 后台对账 → `GET /api/v1/funding/transfers` | P-18 资金记录（状态"已批准"） |
| `GET /accounts/{accountID}/summary/money` | `GET /api/v1/account/money` | P-07 资产卡、P-08 抽屉 |
