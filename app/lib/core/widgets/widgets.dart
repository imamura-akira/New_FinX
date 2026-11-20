import 'package:material_ui/material_ui.dart';

import '../../app/theme.dart';
import 'back_button.dart';

export 'back_button.dart';

/// 与原型 .btn 系列一致的按钮。
enum ButtonKind { primary, secondary, ghost, danger }

class AppButton extends StatelessWidget {
  const AppButton(
    this.label, {
    super.key,
    this.onPressed,
    this.kind = ButtonKind.primary,
    this.small = false,
    this.loading = false,
    this.icon,
    this.fitContent = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final ButtonKind kind;
  final bool small;
  final bool loading;
  final Widget? icon;

  /// 宽度随内容（原型底部"Save & exit"按钮），高度仍为常规 48。
  final bool fitContent;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = switch (kind) {
      ButtonKind.primary => (AppColors.primary, AppColors.onAccent, Colors.transparent),
      ButtonKind.secondary => (AppColors.primaryWeak, AppColors.primary2, Colors.transparent),
      ButtonKind.ghost => (AppColors.surface, AppColors.text, AppColors.line),
      ButtonKind.danger => (AppColors.danger, AppColors.onAccent, Colors.transparent),
    };
    final enabled = onPressed != null && !loading;
    final child = loading
        ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: fg))
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[icon!, const SizedBox(width: 6)],
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis, maxLines: 1)),
            ],
          );
    final radius = BorderRadius.circular(small ? AppShape.smallButtonRadius : AppShape.buttonRadius);
    // 主按钮为 FinX 渐变（design/theme.md grad）；其余为纯色
    final gradient = kind == ButtonKind.primary ? AppGradients.grad : null;
    return Opacity(
      opacity: enabled || loading ? 1 : .4,
      child: SizedBox(
        height: small ? 34 : 48,
        width: small || fitContent ? null : double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(gradient: gradient, color: gradient == null ? bg : null, borderRadius: radius),
          child: TextButton(
            onPressed: enabled ? onPressed : null,
            style: TextButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: fg,
              disabledForegroundColor: fg,
              padding: EdgeInsets.symmetric(horizontal: small ? 12 : 18),
              textStyle: TextStyle(fontSize: small ? 14 : 16, fontWeight: FontWeight.w600),
              shape: RoundedRectangleBorder(
                borderRadius: radius,
                side: BorderSide(color: border),
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// 链接样式按钮（原型 .link-btn）。
class LinkButton extends StatelessWidget {
  const LinkButton(this.label, {super.key, required this.onPressed, this.color, this.fontSize = 14});
  final String label;
  final VoidCallback? onPressed;
  final Color? color; // 默认主题紫
  final double fontSize;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      foregroundColor: color ?? AppColors.primary,
      textStyle: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w500),
      minimumSize: const Size(0, 36),
    ),
    child: Text(label),
  );
}

/// 表单字段（原型 .field：标签 + 输入 + 错误/提示）。
class AppField extends StatelessWidget {
  const AppField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.helper,
    this.error,
    this.keyboardType,
    this.maxLength,
    this.onChanged,
    this.suffix,
    this.obscure = false,
    this.fieldKey,
    this.enabled = true,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final String? helper;
  final String? error;
  final TextInputType? keyboardType;
  final int? maxLength;
  final ValueChanged<String>? onChanged;
  final Widget? suffix;
  final bool obscure;
  final Key? fieldKey;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final input = TextField(
      key: fieldKey,
      controller: controller,
      keyboardType: keyboardType,
      maxLength: maxLength,
      obscureText: obscure,
      enabled: enabled,
      onChanged: onChanged,
      autocorrect: false,
      style: const TextStyle(fontSize: 16),
      decoration: InputDecoration(hintText: hint, counterText: '', errorText: null, enabledBorder: error != null ? _errBorder : null),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: AppColors.muted)),
          const SizedBox(height: 6),
          suffix == null
              ? input
              : Row(
                  children: [
                    Expanded(child: input),
                    const SizedBox(width: 8),
                    suffix!,
                  ],
                ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(error!, style: TextStyle(color: AppColors.danger, fontSize: 12)),
            )
          else if (helper != null)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(helper!, style: TextStyle(color: AppColors.faint, fontSize: 12)),
            ),
        ],
      ),
    );
  }

  static final _errBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppShape.inputRadius),
    borderSide: BorderSide(color: AppColors.danger, width: 1.5),
  );
}

/// 提示条（原型 .notice info / warn / danger / ok）。
enum NoticeKind { info, warn, danger, ok }

class Notice extends StatelessWidget {
  const Notice(this.text, {super.key, this.kind = NoticeKind.info, this.child});
  final String text;
  final NoticeKind kind;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, icon) = switch (kind) {
      NoticeKind.info => (AppColors.infoWeak, AppColors.infoText, Icons.info_outline),
      NoticeKind.warn => (AppColors.warnWeak, AppColors.warnText, Icons.warning_amber_rounded),
      NoticeKind.danger => (AppColors.dangerWeak, AppColors.dangerText, Icons.error_outline),
      NoticeKind.ok => (AppColors.primaryWeak, AppColors.primary2, Icons.check_circle_outline),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: child ?? Text(text, style: TextStyle(color: fg, fontSize: 13, height: 1.55)),
          ),
        ],
      ),
    );
  }
}

/// 两段切换（原型 .seg2）。
class Seg2<T> extends StatelessWidget {
  const Seg2({super.key, required this.items, required this.value, required this.onChanged});
  final List<(T, String)> items;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(11)),
    child: Row(
      children: [
        for (final (v, label) in items)
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(v),
              child: Container(
                height: 34,
                alignment: Alignment.center,
                decoration: v == value
                    ? BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8), boxShadow: AppShape.shadow)
                    : null,
                child: Text(
                  label,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: v == value ? AppColors.text : AppColors.muted),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

/// 卡片（原型 .card）。
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.borderColor});
  final Widget child;
  final EdgeInsets padding;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 12),
    padding: padding,
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppShape.radius),
      boxShadow: AppShape.shadow,
      border: borderColor == null ? null : Border.all(color: borderColor!, width: 1.5),
    ),
    child: child,
  );
}

/// 状态页（原型 .state：图标圆 + 标题 + 说明 + 按钮）。S-01 等复用。
class StateView extends StatelessWidget {
  const StateView({super.key, required this.icon, required this.title, required this.message, this.actions = const []});
  final IconData icon;
  final String title;
  final String message;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(color: AppColors.primaryWeak, shape: BoxShape.circle),
            child: Icon(icon, size: 36, color: AppColors.primary),
          ),
          const SizedBox(height: 18),
          Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 14),
            ),
          ),
          const SizedBox(height: 24),
          for (final a in actions) Padding(padding: const EdgeInsets.only(bottom: 8), child: a),
        ],
      ),
    ),
  );
}

/// 底部操作区（原型 .footer）。
class FooterBar extends StatelessWidget {
  const FooterBar({super.key, required this.children, this.compactBottom = false});
  final List<Widget> children;

  /// 键盘弹出时不再叠加底部安全区内边距。
  final bool compactBottom;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.surface,
      border: Border(top: BorderSide(color: AppColors.line)),
    ),
    padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + (compactBottom ? 0 : MediaQuery.of(context).padding.bottom)),
    child: Row(
      children: [
        for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(width: 10), children[i]],
      ],
    ),
  );
}

/// 页面骨架（原型 .screen：导航栏 + 可滚动内容 + 底部操作区）。
/// 底部操作区随键盘上移（不被键盘遮挡）；点空白处收起键盘。
class PageScaffold extends StatelessWidget {
  const PageScaffold({
    super.key,
    required this.title,
    required this.content,
    this.footer,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 28),
  });
  final String title;
  final List<Widget> content;
  final List<Widget>? footer;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    return Scaffold(
      appBar: AppBar(title: Text(title), leading: const AppBackButton()),
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            Expanded(
              child: ListView(padding: padding, keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag, children: content),
            ),
            if (footer != null) FooterBar(compactBottom: keyboardOpen, children: footer!),
          ],
        ),
      ),
    );
  }
}

/// 轻提示（原型 UI.toast）。
void showToast(BuildContext context, String message) {
  final m = ScaffoldMessenger.maybeOf(context);
  m?.hideCurrentSnackBar();
  m?.showSnackBar(
    SnackBar(
      content: Text(message, textAlign: TextAlign.center),
      duration: const Duration(seconds: 2),
    ),
  );
}
