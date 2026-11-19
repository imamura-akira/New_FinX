# App（Flutter）

美股交易 App 客户端。只调用我方后端（`backend/`，`/api/v1`），不接触任何 DW 凭据或 DW token；会话 token 存于 iOS Keychain。
页面规格以 `design/pages.md` 为准，UI 以 `prototype/` 对应页面为准；接口字段名以 `backend/api/openapi.yaml` 为准。

## 目录（按 feature 分层）

```
lib/
  main.dart                 入口：配置 → ApiClient → SessionController → 路由
  app/                      config（--dart-define）、theme（原型设计令牌）、router（会话驱动重定向）、scope（依赖注入）
  core/api/                 ApiClient：信封解包、错误码映射、Bearer token、401xx 回调
  core/session/             SessionController、TokenStore（Keychain / 内存）
  core/widgets/             与原型一致的按钮、字段、提示条、分段、卡片、状态页
  features/<feature>/data/          接口封装（字段名同 openapi）
  features/<feature>/presentation/  页面
test/                       widget / 单元测试（假后端基于 package:http/testing）
```

## 运行（iOS 模拟器）

1. 启动后端（演示模式：验证码固定 000000，仅 sandbox 可用）：

```bash
cd "/Users/ak/Desktop/Claude FinX New/backend" && (set -a; source ./.env; set +a; OTP_DEV_LOG=true KYC_POLL_INTERVAL=10s go run ./cmd/server)
```

2. 运行 App（模拟器可直接访问本机 127.0.0.1）：

```bash
cd "/Users/ak/Desktop/Claude FinX New/app" && flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8080/api/v1 --dart-define=DEMO_MODE=true
```

`DEMO_MODE=true` 时登录页在发送验证码后提示"演示环境验证码：000000"。

- `DATABASE_URL` 已写入 `backend/.env`（本地 Docker 数据库）。
- 项目位于 iCloud 同步的桌面目录，codesign 会因扩展属性失败，所以 `app/build` 是指向 `~/Library/Caches/finx-app-build` 的符号链接，不要删除。
- 模拟器请使用英文键盘（中文拼音输入法会打乱邮箱输入）。
- 演示流程、备用用户与 `cmd/demoreset` 用法见 `design/demo-script.md`。

## 真机运行（可选）

1. iPhone 与 Mac 连同一局域网；后端改为监听局域网地址：启动命令中加 `HTTP_ADDR=0.0.0.0:8080`。
2. 查 Mac 的局域网 IP（系统设置 → 网络），运行时把 `API_BASE_URL` 换成 `http://<Mac 的 IP>:8080/api/v1`。
3. 在 Xcode 打开 `ios/Runner.xcworkspace`，Runner → Signing & Capabilities 选择你的 Apple 开发者团队（需要你的 Apple ID）。
4. iPhone 开启"开发者模式"（设置 → 隐私与安全性），用数据线连接后 `flutter run -d <设备名> --dart-define=API_BASE_URL=http://<Mac 的 IP>:8080/api/v1 --dart-define=DEMO_MODE=true`。
   首次安装后如提示"不受信任的开发者"：设置 → 通用 → VPN 与设备管理 → 信任你的开发者证书。
5. `Info.plist` 已开启 `NSAllowsLocalNetworking`，只允许访问本地网络地址的 HTTP，对公网仍强制 HTTPS。生产环境后端必须使用 HTTPS。
6. 免费 Apple ID 签名的 App 7 天后失效，演示前一天重新 `flutter run` 安装一次。
7. 真机与 Mac 不在同一网络、或公司网络隔离设备时，App 会提示网络连接失败：改用模拟器演示，或用手机热点把两台设备连到同一网络。

## 检查

```bash
cd "/Users/ak/Desktop/Claude FinX New/app" && flutter analyze && flutter test
```
