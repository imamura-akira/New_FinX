import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:material_ui/material_ui.dart';

/// F21：外观选择（跟随系统 / 浅色 / 深色），Keychain 持久化（与语言选择同一方式）。
/// 默认跟随系统：iOS 切换深浅色时实时生效。
class AppearanceController extends ValueNotifier<ThemeMode> {
  AppearanceController._() : super(ThemeMode.system);
  static final instance = AppearanceController._();

  static const _key = 'app_appearance';
  FlutterSecureStorage? _storage;

  /// 启动时读取已保存的选择（失败按跟随系统）。
  Future<void> load([FlutterSecureStorage? storage]) async {
    _storage = storage ?? const FlutterSecureStorage();
    try {
      value = _parse(await _storage!.read(key: _key));
    } catch (_) {
      value = ThemeMode.system;
    }
  }

  /// 选择外观并保存。
  Future<void> select(ThemeMode mode) async {
    value = mode;
    try {
      final s = _storage;
      if (s == null) return;
      if (mode == ThemeMode.system) {
        await s.delete(key: _key);
      } else {
        await s.write(key: _key, value: mode.name);
      }
    } catch (_) {
      // 保存失败只影响下次启动，不影响当前选择
    }
  }

  static ThemeMode _parse(String? v) => switch (v) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  @visibleForTesting
  void reset() => value = ThemeMode.system;
}
