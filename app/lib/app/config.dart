/// 运行配置（编译期通过 --dart-define 注入，不含任何凭据）。
///
///   flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8080/api/v1 --dart-define=DEMO_MODE=true
///
/// App 只调用我方后端（CLAUDE.md 硬性规则 2），不持有任何 DW 凭据或 DW token。
class AppConfig {
  const AppConfig({required this.apiBaseUrl, required this.demoMode});

  /// 我方后端 /api/v1 地址。iOS 模拟器可直接访问本机 127.0.0.1。
  final String apiBaseUrl;

  /// 演示模式：在登录页提示演示验证码（后端 OTP_DEV_LOG=true 时验证码固定为 000000）。
  final bool demoMode;

  static const AppConfig fromEnvironment = AppConfig(
    apiBaseUrl: String.fromEnvironment('API_BASE_URL', defaultValue: 'http://127.0.0.1:8080/api/v1'),
    demoMode: bool.fromEnvironment('DEMO_MODE'),
  );

  /// F22-e 季节限定主题开关（--dart-define=SEASONAL_THEME=true）：开启时 P-27 奖励 Tab 显示圣诞限定版（F16，代码与素材留档），
  /// 默认关闭 = Fifi 商店。
  static const bool seasonalTheme = bool.fromEnvironment('SEASONAL_THEME');

  /// 品牌名（design/theme.md 第 5 节）。
  static const String appName = 'FinX';
}
