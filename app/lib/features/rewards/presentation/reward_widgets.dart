import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/scope.dart';
import '../../../app/theme.dart';
import '../../../core/sound/ui_sound.dart';
import '../data/rewards_api.dart';
import '../../../l10n/l10n.dart';

String fmtXp(int v) {
  final s = v.abs().toString();
  final b = StringBuffer(v < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}

/// XP 胶囊（⭐ 1,493 XP）：显示真实余额（GET /rewards/xp）；点击进入赚取 XP 任务页（已在任务页时不跳转）。
class XpPill extends StatefulWidget {
  const XpPill({super.key, this.onEarnPage = false});
  final bool onEarnPage;

  @override
  State<XpPill> createState() => _XpPillState();
}

class _XpPillState extends State<XpPill> {
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      XpBalance.instance.refresh(AppScope.of(context).api);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: XpBalance.instance,
    builder: (context, _) {
      final b = XpBalance.instance.balance;
      return GestureDetector(
        key: const Key('xp.pill'),
        onTap: widget.onEarnPage ? null : () => context.push('/rewards/earn'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: StoreColors.xpBorder, width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('⭐', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 5),
              Text(
                t.xpPill(b == null ? '—' : fmtXp(b)),
                key: const Key('xp.value'),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.primary),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Fifi 圆形头像（主色描边）。
class FifiAvatar extends StatelessWidget {
  const FifiAvatar({super.key, this.size = 40});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: AppColors.primaryWeak,
      border: Border.all(color: AppColors.primary, width: 2),
    ),
    child: ClipOval(child: Image.asset(BrandAssets.fifiAvatar, fit: BoxFit.cover, semanticLabel: 'Fifi')),
  );
}

/// 透明通道整卡 PNG：原图直接显示（不加容器裁切），只加沿图形轮廓的投影（定稿 drop-shadow）。
class ShadowedImage extends StatelessWidget {
  const ShadowedImage(this.asset, {super.key, this.semanticLabel});
  final String asset;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final img = Image.asset(asset, width: double.infinity, fit: BoxFit.fitWidth, semanticLabel: semanticLabel);
    return Stack(
      children: [
        Positioned.fill(
          child: Transform.translate(
            offset: const Offset(0, 10),
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 11, sigmaY: 11),
              child: ColorFiltered(
                colorFilter: const ColorFilter.mode(StoreColors.imageShadow, BlendMode.srcIn),
                child: Image.asset(asset, width: double.infinity, fit: BoxFit.fitWidth, excludeFromSemantics: true),
              ),
            ),
          ),
        ),
        img,
      ],
    );
  }
}

/// "开启上线提醒"：开启时"叮"一声 + 轻触感，按钮变为已开启态（仅本次运行有效，与 P-27 原提醒逻辑一致）。
class LaunchReminderButton extends StatelessWidget {
  const LaunchReminderButton({super.key, required this.on, required this.onChanged, required this.label, required this.onLabel});
  final bool on;
  final ValueChanged<bool> onChanged;
  final String label, onLabel;

  static void feedback(bool on) {
    if (on) {
      UiSound.play(UiSound.reminderDing);
      HapticFeedback.lightImpact();
    } else {
      HapticFeedback.selectionClick();
    }
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    toggled: on,
    child: GestureDetector(
      key: const Key('reminder.button'),
      onTap: () {
        feedback(!on);
        onChanged(!on);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? StoreColors.availBg : StoreColors.remindBg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          on ? '✓ $onLabel' : '🔔 $label',
          key: const Key('reminder.label'),
          style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: on ? AppColors.up : AppColors.primary),
        ),
      ),
    ),
  );
}

/// 页头：大标题（可带副题）+ 右侧 XP 胶囊与可选头像 / 搜索。
class RewardHeader extends StatelessWidget {
  const RewardHeader({super.key, required this.title, this.subtitle, this.trailing, this.onEarnPage = false, this.back = false});
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool onEarnPage;
  final bool back;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4, bottom: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (back)
          IconButton(
            key: const Key('nav.back'),
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.chevron_left_rounded, size: 28, color: AppColors.ink),
            onPressed: () => context.pop(),
          ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: AppColors.ink),
              ),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.sub),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        XpPill(onEarnPage: onEarnPage),
        if (trailing != null) ...[const SizedBox(width: 9), trailing!],
      ],
    ),
  );
}
