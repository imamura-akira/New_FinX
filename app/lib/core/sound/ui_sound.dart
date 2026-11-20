import 'package:flutter/services.dart';

/// 界面提示音（design/theme.md 第 7 节）。iOS 由 AppDelegate 以 AVAudioSession `.ambient` 播放：
/// 跟随系统静音开关（静音时只有动效），不打断其他 App 的音乐。其他平台未实现时静默忽略。
abstract final class UiSound {
  static const channel = MethodChannel('finx/ui_sound');

  /// P-01 欢迎页品牌提示音（tool/gen_welcome_chime.py 脚本合成）。
  static const welcomeChime = 'assets/sounds/welcome_chime.wav';

  /// P-27 "开启上线提醒"清脆提示音（tool/gen_reminder_ding.py 脚本合成，约 0.4 秒）。
  static const reminderDing = 'assets/sounds/reminder_ding.wav';

  static Future<void> play(String asset) async {
    try {
      await channel.invokeMethod<bool>('play', {'asset': asset});
    } on MissingPluginException {
      // 平台未实现：无声
    } on PlatformException {
      // 播放失败不影响界面
    }
  }
}
