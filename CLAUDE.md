# 项目规则（CLAUDE.md）— 美股交易 App（DW 沙盒第一阶段）

## 项目是什么
Flutter 客户端 + Go 后端的美股交易 App，券商基础设施为 DriveWealth（DW，UAT 沙盒）。
第一阶段目标：打通沙盒全流程（注册登录 → 开户 → KYC → 开立账户 → 绑卡 → 入金 → 出金）。

## 动手前必读（按序）
1. `design/prd.md` — 范围、DoD、里程碑 M0–M4
2. `design/api-spec.md` — App↔后端接口契约 v1（已冻结）
3. `design/backend-design.md` — 后端架构、DW 客户端、数据模型、配置开关
4. `design/pages.md` — 页面规格（第 5 版，UI 已定稿）；实现某页面时读对应章节
5. `design/ui-signoff.md` — 定稿范围与变更登记规则

## 目录约定
- `app/` — Flutter 客户端（新建）
- `backend/` — Go 后端（新建，结构按 backend-design.md 第 2 节）
- `prototype/` — 已定稿的 HTML 原型，**只读参考，不改**
- `design/` — 设计文档；页面结构变更须登记到 ui-signoff.md 第 3 节变更表

## 硬性规则
1. **凭据**：DW 的 App Key / clientID / clientSecret 只放 `.env`（已在 .gitignore）；不写进代码、文档、日志、提交信息。仓库中出现任何真实凭据或真实账户编号 = 事故。
2. **App 不直连 DW**：所有 DW 调用走 `backend/internal/dwclient`；Flutter 只调我方后端。
3. **待 DW 确认项**：标注 Q-DW-x 的行为一律走 `backend/internal/config` 开关（见 backend-design.md 第 7 节），不许写死。沙盒实测与文档不符时以沙盒为准，并回写 `design/pages.md` 与 `design/api-spec.md` 的变更记录。
4. **接口契约**：改 api-spec.md 必须同步 `backend/api/openapi.yaml`，破坏性变更禁止（升 v2 需用户同意）。
5. **出金安全**：金额、限额、收款人（WIRE 固定为开户姓名）后端强制校验，不信任客户端。
6. **UI 已定稿**：页面结构以 pages.md 为准；发现规格缺口先问用户，不自行改结构。
7. **文案**：用户可见文字用简体中文；时效等规则文案与 pages.md 3.1.5 一致，保留"待 DW 确认"字样。

## Git 同步（每个开发节点必做）
- 远程仓库：`https://github.com/imamura-akira/New_FinX`（main 分支）
- 首次：`git init` → 提交基线 → `git remote add origin ...` → `git push -u origin main`
- **每完成一个里程碑（M0–M4）或一个完整功能模块（F1–F10），立即 commit 并 push**；提交信息格式：`M1-F2: 开户草稿接口与自动保存`
- 提交前自查：`git status` 确认没有 .env、design/reference/、.DS_Store；跑通 `go build ./...` 与 `flutter analyze` 再提交
- 不使用 force push；main 不保护期间也按此纪律执行

## 测试
- 后端：每个 handler 配表驱动单测；dwclient 用 httptest mock DW；沙盒联调用例按 backend-design.md 第 9 节
- Flutter：关键流程（开户表单校验、出入金金额校验）配 widget test
