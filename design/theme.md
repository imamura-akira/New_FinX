# FinX 主题规格（theme.md）

> 来源：用户提供的 20 张 FinX 样板截图（品牌与 Fifi 吉祥物为我方自有资产）。
> 用途：原型 `prototype/css/app.css` 与 Flutter 主题（`app/` ThemeData）共同的唯一视觉依据。
> 规则：页面结构与交互不变（UI 定稿第 5 版），本规格只定义视觉层。

## 1. 色彩

| Token | 值 | 用途 |
|---|---|---|
| bg | `#F6F5FC` | 页面背景（浅薰衣草） |
| surface | `#FFFFFF` | 卡片 |
| surface-2 | `#F3F2FA` | 次级底、图标底 |
| text | `#171A2E` | 主文字 |
| muted / faint | `#6B7191` / `#9BA0B8` | 次要文字 |
| line | `#E9E8F4` | 分隔线、描边 |
| **primary** | `#6C5BF5` | 主色（紫罗兰）：链接、选中态、图标 |
| primary-2 | `#4F3ED9` | 主色深 |
| primary-weak | `#EFECFE` | 主色浅底（badge、选中底） |
| accent | `#3B82F6` | 蓝色辅助（市场模块可用） |
| up / down | `#16A34A` / `#E5484D` | 涨跌（美式绿涨红跌，red-up 开关保留） |
| **grad** | `100deg: #5A57EE → #A944D8 55% → #D63AA8` | 主 CTA 按钮渐变 |
| grad-soft | `135deg: #7D4DF0 → #C13AC8` | 小选中态、mark |
| hero | `135deg: #7D4DF0 → #A944D8 → #D63AA8` | 资产总览大卡 |
| soon | `120deg: #4A43E8 → #8A3FE0 → #D63AA8` | 预告卡（Fifi/奖励，奖励尾端可换 `#F0A13C` 橙） |
| 资产配置色 | cash `#6C5BF5` / stock `#D63AA8` / etf `#F0A13C` | 环图 |

欢迎页注册按钮可用三段暖渐变 `#5A57EE → #C93BB0 → #F09B3C`（对应样板 Sign up）。

## 2. 形状与投影

- 卡片圆角 18px（大卡 22px）；主按钮全圆角（高 48 → 半径 24）；小按钮半径 17px。
- 投影：`0 1px 2px rgba(42,34,96,.05), 0 6px 18px rgba(42,34,96,.07)`（带紫味的柔和投影）。
- 筛选胶囊选中态：grad-soft 渐变底白字；未选中白底描边。

## 3. 字体

- 中文 PingFang SC / 西文系统无衬线；数字 tabular-nums。
- 层级与现行原型一致；页面大标题 26/700。

## 4. 品牌素材（prototype/assets/）

| 文件 | 内容 | 用在 |
|---|---|---|
| logo.png | FiNX 渐变字标 + "GO FinX Go Alpha" 手写标语 | P-01 欢迎页 |
| fifi_pill.png | Fifi 趴在胶囊上（眨眼） | P-01 欢迎页主视觉 |
| fifi_paw.png | Fifi 举爪 + 爪形图表 logo | P-26 Fifi 预告卡；可用于空状态 |
| fifi_avatar.png | Fifi 圆形头像（透明底） | 账户抽屉、Fifi 相关入口 |
| cat_xmas.png（app/assets/brand/，来源 design/reward-design/） | 圣诞毛衣 + 圣诞帽 Fifi，眨眼举爪，已抠图透明背景（427×601） | P-27 奖励页英雄区（F16 圣诞季限定） |
| ak_mark.png（app/assets/brand/，来源 design/brand/ak_mark.png，缩至 600px 宽） | AK 立体字标（白 / 橙 / 黑描边，透明背景） | P-01 欢迎页字标（F20，约 200pt 宽，按轮廓的轻投影） |
| ak_mark_icon_1024.png（design/brand/） | **App 图标母版（2026-11-20 晚起）**：白底 1024×1024（无透明通道），AK 立体字标（白 / 橙 / 黑描边，与 P-01 欢迎页字标同款） | iOS AppIcon 全尺寸（15 个）由此生成；App 显示名称 AK Stocks |
| ak_icon_1024.png（design/brand/） | 深蓝圆徽 "AK" 图标母版（v1.7 使用），**保留备查**，不再用于 AppIcon | 已停用 |
| app_icon_1024.png（design/brand/） | 原 FinX Stocks 图标母版（渐变爪印 + 涨幅柱，来源 app_icon_source.png），**保留备查**，不再用于 AppIcon | 已停用 |
| logo_dark.png / fifi_pill_dark.png（app/assets/brand/，由 logo.png / fifi_pill.png 经 tool/gen_welcome_dark_assets.py 生成） | 透明底版本（原图为 RGB 白底，深色下会出现白块）：字标为颜色转透明，胶囊图为外部背景泛洪去除 | P-01 深色模式（F22-g，字标下加浅色辉光） |
| fifi_order.png（design/brand/ → app/assets/brand/，缩至 720px） | Fifi 举回执（透明背景） | F22-c 成交成功页 |
| fifi_quant.png（design/brand/，原图 240×333） | Fifi 拿平板（透明背景）；**分辨率偏低，3x 屏略糊，建议补高清图** | F22-d P-26 英雄卡 |
| store/st_hero_full.png、store/xp_hero.png（design/brand/store/ → app/assets/brand/store/，缩至 1110px 宽） | 商店 / 任务页英雄横幅，透明通道整卡 PNG（已回正），原图显示、不裁切、仅投影；中英文同图（图中文字为英文） | F22-e P-27、F22-f 任务页 |
| store/st_jacket / st_vest / st_bag / st_phones（缩至 330px） | 商品高清图（棒球夹克、交易马甲、紫色挎包、量化耳机） | F22-e 商品卡 |
| store/st_garage / st_home / st_yacht / st_jet（design/brand/store/ → 缩至 480px 宽，原 1374×1145） | "敬请期待"高清成品卡图（自带圆角，透明边）：原图直接显示（AspectRatio 1.2，容器不裁切），锁角标 StoreColors.lockBadge 叠加在图右上角 | F22-e 敬请期待 |
| store/st_bundle_banner（缩至 1086px 宽，原 2172×724） | 限定分析师套装整条横幅：标题、XP、Preview 按钮已内嵌（英文，中英模式通用），整卡可点进入预览弹层；不再原生渲染标题 / 价格 / 按钮 | F22-e 套装 |
| store/st_bundle_placeholder / st_garage_placeholder / st_home_placeholder / st_yacht_placeholder / st_jet_placeholder | **已停用，保留备查**（低分辨率占位图，seed 不再引用） | — |
| （无素材）等级 1、2 小商品：贴纸包、徽章、手机壳、棒球帽 | **待配图**：seed 中 image 为空、placeholder=true、color=#RRGGBB，App 渲染纯色圆角块 + "待配图 / Art coming soon"；深色下纯色降至 45% 不透明度。配图到位后放入 store/st_<id>.png 并在 seed 填 image | F22-e 商品卡 |

规则：素材为我方品牌资产，可在任何页面使用；新素材先入 `assets/` 并登记到本表。
样板中出现的真实投资人照片（股票大师页）**不进入**原型与正式 App，继续用字母头像；
样板奖励商店中的实物商品图（含第三方品牌运动鞋等）不直接复用，正式素材需为自制或有授权。

## 4.5 开户流程版式（参考样板，已实现于原型）

- 顶部分段进度条（每步一段，完成段用 grad-soft），下方 "STEP X OF N" 字距拉开小标。
- 每步一个大标题（28/800）+ 一句说明（15/muted）；说明句承担合规话术。
- 敏感输入（税号）默认遮罩，右侧 Show/Hide；底部配 "Encrypted in transit and at rest" 锁形提示。
- 底部双按钮同行：Save & exit（ghost，自适应宽）+ Continue（渐变主按钮，占满剩余）。

## 5. 文案与命名

- 品牌名：FinX（APP_NAME）；**App 显示名称：AK Stocks**（主屏图标下方 / CFBundleDisplayName，中英文环境均不翻译；2026-11-20 由 FinX Stocks 改名）；吉祥物：Fifi。
- 底部 Tab：首页(资产) / 市场 / 股票大师 / Fifi / 奖励。
- **语言**：开户与 KYC 模块（P-03–P-06、P-30、P-34–P-36）界面与用户输入一律英文；其余模块简体中文。英文文案以原型为基准。
- P-23 对外名称"股票大师"（规格内部编号与数据口径不变，13F 公开申报数据）。

## 6. Flutter 落地要点

- 以上 token 做成 ThemeExtension；渐变用 LinearGradient 常量。
- 素材从 assets/ 原样拷入 Flutter assets 并在 pubspec 声明。
- 深色模式：F21 起支持（见第 10 节）。令牌在 `app/lib/app/theme.dart`：`AppPalette.light / dark` 两套色板，`AppColors.*` 等为按当前外观取值的 getter；页面一律走令牌，不写死颜色。

## 7. 动效

**成功时刻庆祝**（产品功能，DEMO_MODE 与正式模式都生效；实现：`app/lib/core/widgets/celebration.dart`）

| 场景 | 触发 | 效果 | 触感 |
|---|---|---|---|
| 开户成功（P-06） | 账户状态由未开立变为 OPEN、出现 "Your live account is open" 的那一刻；刚提交（15 分钟内）的申请首次加载即 OPEN 也算 | 完整版：约 90 片彩带 / 圆点 + 7 个白色爪印 | `HapticFeedback.mediumImpact` 一次 |
| 入金提交成功（P-13 结果页） | 券商受理成功（结果待确认 50001 时不播） | 轻量版：约 32 片 + 3 个爪印 | 无 |
| 下单成功（P-19 结果页，F14） | 券商受理且未拒绝（结果待确认或 REJECTED 时不播） | 轻量版（同入金） | 无 |

- 色彩：品牌渐变色系 #5A57EE → #7D5CF0 → #A944D8 → #C13AC8 → #D63AA8，外加浅紫 #B9B2FF；爪印为白色带淡紫描边（浅底可见）。
- 运动：从屏幕顶部撒下，随机横向摆动与旋转，错峰出现，最后 20% 时间淡出；总时长约 2 秒。
- 不阻挡内容：覆盖在最上层但不拦截点击（IgnorePointer），播完自动移除；无声音。
- 只播一次：同一账户号码 / 同一笔入金流水在本次运行中只播放一次，状态页轮询刷新、页面重建与重新进入都不重播。
- 无障碍：系统开启"减弱动态效果"时不播放动画（触感保留）。

**P-01 品牌入场 + 高点"滴"声**（F20 AK 品牌版，2026-11-20 起替换原 FiNX 字标滑入 + Fifi 弹跳与钟声和弦；实现：`app/lib/features/auth/presentation/welcome_page.dart`、`app/lib/core/sound/ui_sound.dart`、iOS `AppDelegate.swift`）

| 项 | 规格 |
|---|---|
| 触发 | 冷启动后第一个出现的页面是 P-01 时播放一次；冷启动直接进入资产页（已登录）则不播，之后退出登录回到 P-01 也不播；离开 P-01 再回来不重播（直接显示完整趋势线） |
| 动效（约 2.05 秒） | 0–0.41 s：AK 字标淡入；0.12–0.53 s：slogan 淡入；0.2–0.62 s：按钮区淡入；0.3–1.65 s：趋势线从左向右描画（easeInOutCubic，按路径长度推进，线下淡橙填充随之推进）；1.65 s：终点光点亮起并呼吸 3 次（每次 2.4 秒，其后常亮）；1.65–2.05 s："注册"按钮 1.0 → 1.04 → 1.0 放大一次 |
| 高点"滴"声 | 路径的 5 个阶段性高点（3 个局部高点 (48,108)(128,86)(206,58)、上升由陡转缓的拐点 (284,30)、终点 (322,14)）：描画越过每个高点时"滴"一声，音调依次升高（C6 → E6 → G6 → A6 → C7，大调五声音阶上行）。每声约 100 ms，正弦基音 + 少量泛音、快速衰减，峰值约 -16 dBFS。**由脚本 `app/tool/gen_peak_ticks.py` 合成（仅用 Python 标准库），不使用任何外部音频素材**；产物 `app/assets/sounds/peak_1.wav … peak_5.wav`（各约 9 KB） |
| 减弱动态效果 | 系统开启时直接显示完整静态线与终点光点，不描画、不放大、不呼吸、**不播声音** |
| 可用性 | 动画期间按钮始终可点，不阻塞登录 / 注册 |
| 静音 | iOS 以 AVAudioSession `.ambient` + `mixWithOthers` 播放：跟随系统静音开关（静音时只有动效），不打断用户正在播放的音乐；多声连续播放互不截断；其他平台未实现时无声 |

> 原 P-01 钟声和弦（welcome_chime.wav）及其生成脚本已移除（git 历史可查）。

**模拟盘标识**（F15；实现：`app/lib/features/trading/presentation/paper_widgets.dart`）

| 元素 | 规格 |
|---|---|
| 色系 | 琥珀色：文字 / 角标底 #B45309，横幅与卡片底 #FFF4E0，描边 #F5C46B——与实盘紫色系明显区分 |
| 横幅 | 模拟模式下每个交易相关页面顶部常驻："模拟盘 · 虚拟资金，按演示行情撮合，不产生真实交易"（实验瓶图标） |
| 角标 | 标题旁白字"模拟"圆角标签 |
| 资产卡 | 模拟账户卡用琥珀底 + 描边，替代紫色渐变的实盘资产卡；两者不同时出现 |

## 8. P-27 奖励页圣诞季版式（F16）

定稿：`design/reward-design/rewards_mock_v8.png`；颜色与奖品图形取自同目录 `mock_reference.html`。实现：`app/lib/features/discover/presentation/rewards_page.dart`（`RewardColors`）。节后切回常规版时整体替换该页。

| 元素 | 规格 |
|---|---|
| 英雄区底色 | 浅紫渐变 135deg **#F2EDFC → #F7F2FC（55%）→ #F6EBF7**，1px 描边 **#E7E0F7**，圆角 24，投影 rgba(108,91,245,.16) 0 16 36；左上 #D9CEF8、右下 #F3CBE8 柔光 |
| 英雄区文字 | 标题 #241F4E（25pt，"即将开启"一行字重略轻）；说明 #5F5880（13pt，行高 1.7，宽 184） |
| 徽章 | "圣诞 · 新年限定"：描边 #D4B46A、文字 #9A7524、底 rgba(233,200,120,.14)，雪花用图标（避免 iOS 渲染成蓝色 emoji） |
| 金色胶囊 | "🎁 即将推出"：135deg #F6E7BF → #E9C878，文字 #2E2752 |
| 彩灯串 / 雪点 | 灯线 rgba(108,91,245,.3)；灯泡金 #E9C878 与浅紫 #A08CF0 交替（外圈 25% 光晕）；雪点 #C9B9F2 |
| 吉祥物 | cat_xmas.png，英雄区右下，高 236 |
| 等级胶囊 | 四个等宽占满一行；选中 135deg #7D4DF0 → #C13AC8 白字；未选中白底、1.5px #E4E0F5 描边、#7A7490 字 + 金色锁 #C9A14E |
| 奖品卡 | 白底圆角 20，1px 渐变细描边（紫 #7D4DF0 35% → 金 #E9C878 40% → 玫红 #D63AA8 30%）；奖品图底座为径向浅紫 #F1EDFF → #FAF8FF；名称 #1B1830；金星 #C9A14E + XP 紫 #6C5BF5；"即将推出"胶囊底 #F1EFFA；右上锁角标底 #F3F0FC |
| 提醒按钮 | 未开启：主 CTA 渐变 #5A57EE → #A944D8 → #D63AA8，白字"🔔 开启上线提醒"；已开启：底 #EFECFE、描边 #D9D4F7、紫字"✓ 已开启提醒" |
| 底部小字 | #A7A1BC，11pt |
| 提醒提示音 | 开启时播放一声约 0.4 秒的清脆"叮"：A6（1760 Hz）正弦基音 + 少量谐波与钟声式非谐波泛音，3 ms 起音、短指数衰减，比 P-01 欢迎和弦更短促明亮，峰值约 -16 dBFS。**由脚本 `app/tool/gen_reminder_ding.py` 合成（仅用 Python 标准库），不使用任何外部音频素材**；产物 `app/assets/sounds/reminder_ding.wav`（约 35 KB）。播放方式同第 7 节（`.ambient` + `mixWithOthers`：跟随静音开关，不打断音乐）；同时 `HapticFeedback.lightImpact` 一次；取消提醒不出声 |

## 9. P-01 欢迎页 AK 品牌版配色（F20）

定稿：`design/reward-design/welcome_v3.png`；版式与趋势线路径参考同目录 `welcome_reference.html`。**橙色为欢迎页专属强调色，App 内部主题仍为紫色系（第 1 节）。**

| 元素 | 规格 |
|---|---|
| 背景 | #F6F5FC（与 App 背景一致） |
| 字标 | ak_mark.png，宽约 200pt，轮廓投影 rgba(27,24,48,.18)、模糊 13、下移 16 |
| slogan | 两行居中，#7A7490，14.5pt，字重 600，行高 1.7 |
| 趋势线 | SVG 路径 viewBox 342×150 等比缩放；描边 4pt 圆角，横向渐变 #FEA81E（50% 透明）→ #F58500；线下填充 #FE9502 由 14% → 0 纵向渐变；终点光点 #F58500 半径 5.5，外圈 #FE9502 22% 半径 10（呼吸时放大至 13） |
| 注册按钮 | 135deg #FEA81E → #F58500 全圆角，高 56，白字 17pt 800，投影 rgba(254,149,2,.38) 0 10 24 |
| 登录按钮 | 白底，1.5px #E4E0F5 描边，全圆角，高 54，#1B1830 字 |
| 先逛逛行情 | #6C5BF5（主题紫），14.5pt 700 |
| 免责 | #A7A1BC，12pt |

## 10. 深色模式（F21）

**规则**：默认跟随系统（iOS 关灯 = 深色、开灯 = 浅色，实时切换）；账户抽屉"语言"下方新增"外观 / Appearance"：跟随系统 / 浅色 / 深色，选择持久化（Keychain）。全部页面支持，含开户 / KYC 英文模块、图表、弹层、输入框、Tab 栏、启动图与庆祝特效。

**核心色板**（`AppPalette.dark`；带 * 为需求给定值，其余为按同一色相推导的配套值）

| 令牌 | 浅色 | 深色 | 用途 |
|---|---|---|---|
| bg | `#F6F5FC` | `#141220` * | 页面背景 |
| surface | `#FFFFFF` | `#1E1B2E` * | 卡片 / 弹层 / 输入框 / Tab 栏 |
| surface2 | `#F3F2FA` | `#252238` | 次级底、图标底 |
| line | `#E9E8F4` | `#2A2740` * | 分隔线、描边 |
| text | `#171A2E` | `#F2F0FA` * | 主文字 |
| muted | `#6B7191` | `#9B95B5` * | 次级文字 |
| faint | `#9BA0B8` | `#6F6A8A` | 弱文字、占位 |
| primary | `#6C5BF5` | `#8F7BF8` * | 品牌紫（深色下提亮一档） |
| primary2 / primaryWeak | `#4F3ED9` / `#EFECFE` | `#A99BFA` / `#2A2548` | 强调文字 / 选中底 |
| up / down | `#16A34A` / `#E5484D` | `#22C55E` * / `#F87171` * | 涨 / 跌 |
| upWeak / dangerWeak | `#E8F7EE` / `#FDEDEE` | `#15301F` / `#3A1E26` | 涨跌浅底 |
| warn / warnWeak | `#B45309` / `#FFF6E5` | `#F59E0B` / `#2E2516` | 提示条 |
| infoWeak / infoText | `#EDF2FD` / `#1E3A5F` | `#1C2440` / `#B4C8EE` | 信息条 |
| ink / sub / hint | `#1B1830` / `#7A7490` / `#A7A1BC` | `#F2F0FA` / `#9B95B5` / `#77718F` | F11 之后新版卡片文字 |
| track / pill / chip | `#F1EFF8` / `#F1EFFA` / `#F4F2FB` | `#2A2740` / `#2A2740` / `#252238` | 图表网格、轨道、胶囊 |
| onAccent | `#FFFFFF` | `#FFFFFF` | 渐变 / 实色按钮上的文字 |
| 卡片投影 | 淡紫灰 5–7% | 黑 28–35% | 深底上淡紫影不可见，改黑影 |

**不变**：渐变（主按钮、资产大卡、预告卡、等级胶囊）与主按钮两套相同；P-01 欢迎页 AK 字标与橙色趋势线、注册按钮不变；头像底色、BTC 橙、星标不变。

**模块深色版**

| 模块 | 深色处理 |
|---|---|
| 模拟盘（琥珀） | 文字 / 角标 `#F5A524`，横幅底 `#2E2414`，描边 `#6B4E1C` |
| 演示角标 / 金色点缀 | 金色提示底 `#2E2716`、文字 `#E9B949`；P-27 金色 `#E9C878` 不变，徽章文字改金色 `#E9C878`、金色胶囊上的文字固定 `#2E2752` |
| P-27 奖励页 | 英雄区改深紫渐变 `#2A2350 → #231E3D → #2E1F3E`，柔光降为 25–40% 不透明；奖品图底改深紫径向柔光；插画藏青轮廓提亮为 `#C9C2F5` |
| 市场情绪 | 档位文字提亮（`#F87171` / `#FB923C` / `#9B95B5` / `#E9B949` / `#22C55E`），底色压暗；仪表盘弧线改用深色涨跌色，指针 `#E4E0F5` |
| 图表 | 行情线、资产环形图、趋势线、15 分钟预测线的网格与坐标文字均走 track / hint 令牌；环形图深色 现金 `#8F7BF8`、股票 `#E35DB8`、ETF `#F5B04F` |
| 庆祝特效 | 彩带提亮一档：`#7B78FF #9B80FF #C46BEB #DA62DE #F062C2 #D4CFFF`；爪印保持白色，描边 `#9B80FF` |
| P-01 欢迎页 | 背景换深底；AK 字标外加一圈浅色光晕（白 45%、模糊 7，替代浅色下的下方投影），黑描边在深底上可辨；登录按钮深底 + `#2F2B45` 描边 |
| 弹层 / 输入框 / Tab 栏 / SnackBar | 底为 surface，描边 line；SnackBar 底 `#37334F`（92%） |
| 状态栏 | 深色下白字、浅色下黑字（含无 AppBar 的页面） |
| iOS 启动图 | LaunchScreen 背景改为资源色 `LaunchBackground`（浅 `#F6F5FC` / 深 `#141220`）；LaunchImage 增加深色变体（由 `app/tool/gen_launch_dark.py` 从浅色版生成：浅底替换为深底，渐变爪印不变） |

**实现约束**：页面不写死颜色（`Color(0x…)` / `Colors.white` 等只允许出现在 theme.dart）；新增颜色先加令牌（两套值）再使用。切换外观时整棵树重建并重绘（CustomPainter 也随之换色）。测试 `app/test/dark_mode_test.dart` 会扫描深色下页面中的浅色实色块。

## 11. F22 改版令牌（2026-11-21，定稿 design/reward-design/v3/）

均在 `app/lib/app/theme.dart`，渐变类深浅色相同，其余提供深色版：

| 令牌 | 值 | 用途 |
|---|---|---|
| AppGradients.assetHero | 118deg #4D5BEF → #8A4BE0 42% → #D4569B 70% → #F0944C | P-07 资产大卡 |
| AppGradients.filterOn | 135deg #7D4DF0 → #A944D8 | P-07 筛选胶囊选中 |
| AssetHeroColors | 涨 #7CF2A4 / 跌 #FFC9CB（渐变上）、眼睛底白 22%、系列色（股票 / 现金 / ETF / 青 / 绿 / 灰） | P-07 |
| MarketColors.indexGrads | #5A57EE→#8A4BE0、#A944D8→#D4569B、#E0638A→#F0944C | P-09 指数卡 |
| MarketColors | 平档柱 #C9C4DC、内部人三卡底（绿 / 红 / 紫）、演示角标琥珀 | P-09 |
| OrderDoneColors | 波浪 #D9CEF8→#EFEAFB→#F6F3FE、徽章环 #EFEBFE、闪光 #A98FF5、金币紫 / 金、箭头 #16A34A | 成交成功页 |
| StoreColors.grad | 100deg #7D4DF0 → #A944D8 55% → #D63AA8 | 商店 / 任务 CTA、选中等级 |
| StoreColors.fifiHero | 118deg #4D4FE0 → #7D4DF0 40% → #B44BD8 72% → #E08BC8 | P-26 英雄卡 |
| StoreColors（其余） | XP 胶囊描边 #D9D2F5、等级胶囊、可兑换绿底、已完成行绿底 #EDF9F1、火焰底 #FDEDE4、投影紫 25% | P-27、任务页 |
| WelcomeColors.logoGlow | 白 90% | P-01 深色字标辉光 |

动效与声音：成交成功页弹出时播完整彩带 + `order_success.wav`（tool/gen_order_success.py 合成 C6–E6–G6–C7 上行琶音，约 0.7 秒）+ 中等触感；签到与"开启上线提醒"沿用 `reminder_ding.wav`。P-01 恢复 `welcome_chime.wav`（tool/gen_welcome_chime.py）。

## 变更记录

| 日期 | 内容 |
|---|---|
| 2026-11-19 | v1：从 20 张样板截图提炼；原型全量换肤（v=10） |
| 2026-11-19 | v1.1：开户流程版式（分段进度条/大标题/税号遮罩）；开户与 KYC 模块全英文（v=11） |
| 2026-11-19 | v1.2：确定 App 图标（渐变爪印，母版 design/brand/app_icon_1024.png）与显示名称 FinX Stocks |
| 2026-11-20 | v1.3：新增第 7 节动效——开户成功与入金成功的庆祝特效（紫罗兰渐变彩带 + 白色爪印，约 2 秒，只播一次） |
| 2026-11-20 | v1.5：第 7 节新增"模拟盘标识"（琥珀色横幅、角标、模拟账户卡，F15） |
| 2026-11-20 | v1.4：第 7 节新增 P-01 冷启动品牌入场（字标滑入 + Fifi 弹跳落位与摆动，1.6 秒）与脚本合成提示音（跟随静音开关）；庆祝特效补登 P-19 下单成功（轻量版） |
| 2026-11-20 | v1.6：第 4 节登记 cat_xmas.png（圣诞毛衣 Fifi）；新增第 8 节 P-27 奖励页圣诞季版式（浅紫英雄区配色、等级胶囊、奖品卡、提醒按钮与脚本合成"叮"提示音，F16） |
| 2026-11-20 | v1.7：品牌更新——App 图标改用 design/brand/ak_icon_1024.png（"AK" 徽标）为母版重新生成 iOS AppIcon 全部尺寸；App 显示名称（CFBundleDisplayName）由 FinX Stocks 改为 AK Stocks，中英文环境均显示 AK Stocks、不翻译；原 FinX Stocks 图标母版 app_icon_1024.png 保留备查。启动图与 App 内品牌素材（FinX 字标、Fifi）本次不变 |
| 2026-11-20 | v1.8：F20 欢迎页 AK 品牌版——第 4 节登记 ak_mark.png；第 7 节 P-01 入场改为字标淡入 + 橙色趋势线描画 + 5 个高点音调递增"滴"声 + 光点呼吸 + 注册按钮放大一次（替换原 Fifi 入场与钟声和弦）；新增第 9 节欢迎页橙色配色（欢迎页专属，App 内部仍为紫色系） |
| 2026-11-20 | v1.9：App 图标母版改用 design/brand/ak_mark_icon_1024.png（AK 立体字标）重新生成 iOS AppIcon 全部尺寸，替换深蓝圆徽版（ak_icon_1024.png 保留备查）；第 5 节显示名称更正为 AK Stocks |
| 2026-11-20 | v2.0：F21 深色模式——新增第 10 节（深色色板、模块深色版、欢迎页字标光晕、启动图深色变体、实现约束）；第 6 节改为已支持深色；全 App 硬编码颜色收编为主题令牌 |
| 2026-11-21 | v2.1：F22 改版——第 4 节登记 F22 新素材（占位图标注待替换、fifi_quant 分辨率偏低）与欢迎页深色透明底版本；新增第 11 节 F22 令牌与成交提示音；P-01 回滚为 FinX 原版（第 9 节 AK 橙色配色与第 7 节高点滴声留档，不再使用） |
