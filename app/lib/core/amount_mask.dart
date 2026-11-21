import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// F22-a 资产页"眼睛"：隐藏后全页金额显示为 ****（含图例金额；百分比保留），Keychain 持久化（与语言 / 外观同一方式）。
class AmountMask extends ValueNotifier<bool> {
  AmountMask._() : super(false);
  static final instance = AmountMask._();

  static const _key = 'app_hide_amounts';
  static const masked = '****';
  FlutterSecureStorage? _storage;

  /// 启动时读取（失败按显示金额）。
  Future<void> load([FlutterSecureStorage? storage]) async {
    _storage = storage ?? const FlutterSecureStorage();
    try {
      value = await _storage!.read(key: _key) == '1';
    } catch (_) {
      value = false;
    }
  }

  /// 切换并保存。
  Future<void> toggle() => set(!value);

  Future<void> set(bool hide) async {
    value = hide;
    try {
      final s = _storage;
      if (s == null) return;
      if (hide) {
        await s.write(key: _key, value: '1');
      } else {
        await s.delete(key: _key);
      }
    } catch (_) {
      // 保存失败只影响下次启动
    }
  }

  /// 隐藏时返回 ****，否则原文。
  String apply(String text) => value ? masked : text;

  @visibleForTesting
  void reset() => value = false;
}
