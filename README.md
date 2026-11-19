# New_FinX — 美股交易 App（DriveWealth 沙盒 · 第一阶段）

Flutter 客户端 + Go 后端，券商基础设施为 DriveWealth（UAT 沙盒）。
第一阶段目标：打通沙盒全流程（注册登录 → 开户 → KYC → 开立账户 → 绑卡 → 入金 → 出金）。

## 目录

| 目录 | 内容 |
|---|---|
| `design/` | PRD、页面规格（已定稿）、接口契约、后端方案、DW 问题单、合规映射 |
| `prototype/` | 可点击 HTML 原型（37 页，v8，已定稿；本地起静态服务器即可预览） |
| `app/` | Flutter 客户端（开发中） |
| `backend/` | Go 后端（开发中） |

## 开发入口

- 项目规则：`CLAUDE.md`（Claude Code 自动读取）
- 需求与里程碑：`design/prd.md`
- 接口契约：`design/api-spec.md`
- 后端方案：`design/backend-design.md`

## 安全

- 凭据只放 `.env`（已 gitignore），仓库内不得出现任何真实 Key 或账户编号。
- `design/reference/`（参考截图与合作方文件）不入库。
