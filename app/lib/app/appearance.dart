import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:material_ui/material_ui.dart';

/// F21：外观选择（跟随系统 / 浅色 / 深色），Keychain 持久化（与语言选择同一方式）。
/// F22-0：首次安装（未保存过选择）默认浅色；选"跟随系统"时显式保存 'system'（iOS 切换深浅色时实时生效），
/// 与默认英文语言的处理方式一致。
class AppearanceController extends ValueNotifier<ThemeMode> {
  AppearanceController._() : super(defaultMode);
  static const defaultMode = ThemeMode.light;
  static final instance = AppearanceController._();

  static const _key = 'app_appearance';
  FlutterSecureStorage? _storage;

  /// 启动时读取已保存的选择：未保存（首次安装）或读取失败 = 浅色。
  Future<void> load([FlutterSecureStorage? storage]) async {
    _storage = storage ?? const FlutterSecureStorage();
    try {
      value = _parse(await _storage!.read(key: _key));
    } catch (_) {
      value = defaultMode;
    }
  }

  /// 选择外观并保存。
  Future<void> select(ThemeMode mode) async {
    value = mode;
    try {
      final s = _storage;
      if (s == null) return;
      await s.write(key: _key, value: mode.name);
    } catch (_) {
      // 保存失败只影响下次启动，不影响当前选择
    }
  }

  static ThemeMode _parse(String? v) => switch (v) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    'system' => ThemeMode.system,
    _ => defaultMode,
  };

  @visibleForTesting
  void reset() => value = defaultMode;
}
