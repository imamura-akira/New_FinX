import 'package:material_ui/material_ui.dart';

import '../../app/theme.dart';

/// 表单组件（与原型 .field / .yn / .check / .chip / .kv / .badge 一致）。

/// 字段外壳：标签 + 内容 + 错误 / 提示。
class FieldShell extends StatelessWidget {
  const FieldShell({super.key, required this.label, required this.child, this.error, this.hint});
  final String label;
  final Widget child;
  final String? error;
  final String? hint;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[Text(label, style: const TextStyle(fontSize: 13, color: AppColors.muted)), const SizedBox(height: 6)],
        child,
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(error!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
          )
        else if (hint != null)
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(hint!, style: const TextStyle(color: AppColors.faint, fontSize: 12)),
          ),
      ],
    ),
  );
}

BoxDecoration _boxDecoration(bool error) => BoxDecoration(
  color: AppColors.surface,
  borderRadius: BorderRadius.circular(AppShape.inputRadius),
  border: Border.all(color: error ? AppColors.danger : AppColors.line, width: 1.5),
);

/// 单选下拉：点开底部选择列表（选项多于 15 个时带搜索框）。
class SelectField extends StatelessWidget {
  const SelectField({
    super.key,
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
    this.error,
    this.hint,
    this.placeholder = 'Select',
    this.sheetTitle,
    this.fieldKey,
  });

  final String label;
  final List<(String, String)> options;
  final String? value;
  final ValueChanged<String> onChanged;
  final String? error;
  final String? hint;
  final String placeholder;
  final String? sheetTitle;
  final Key? fieldKey;

  @override
  Widget build(BuildContext context) {
    String? text;
    for (final (v, l) in options) {
      if (v == value) text = l;
    }
    return FieldShell(
      label: label,
      error: error,
      hint: hint,
      child: InkWell(
        key: fieldKey,
        borderRadius: BorderRadius.circular(AppShape.inputRadius),
        onTap: () async {
          FocusScope.of(context).unfocus();
          final picked = await showModalBottomSheet<String>(
            context: context,
            isScrollControlled: true,
            backgroundColor: AppColors.surface,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
            builder: (_) => _OptionSheet(title: sheetTitle ?? label, options: options, selected: value),
          );
          if (picked != null) onChanged(picked);
        },
        child: Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: _boxDecoration(error != null),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  text ?? placeholder,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 16, color: text == null ? AppColors.faint : AppColors.text),
                ),
              ),
              const Icon(Icons.expand_more_rounded, color: AppColors.faint),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionSheet extends StatefulWidget {
  const _OptionSheet({required this.title, required this.options, this.selected});
  final String title;
  final List<(String, String)> options;
  final String? selected;

  @override
  State<_OptionSheet> createState() => _OptionSheetState();
}

class _OptionSheetState extends State<_OptionSheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final searchable = widget.options.length > 15;
    final list = widget.options.where((o) => _q.isEmpty || o.$2.toLowerCase().contains(_q.toLowerCase())).toList();
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .75),
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Text(widget.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              ),
              if (searchable)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: TextField(
                    key: const Key('select.search'),
                    autofocus: false,
                    decoration: const InputDecoration(hintText: 'Search', prefixIcon: Icon(Icons.search_rounded)),
                    onChanged: (v) => setState(() => _q = v),
                  ),
                ),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.line, indent: 16, endIndent: 16),
                  itemBuilder: (_, i) {
                    final (v, l) = list[i];
                    final on = v == widget.selected;
                    return ListTile(
                      key: Key('option.$v'),
                      title: Text(
                        l,
                        style: TextStyle(
                          fontWeight: on ? FontWeight.w600 : FontWeight.w400,
                          color: on ? AppColors.primary2 : AppColors.text,
                        ),
                      ),
                      trailing: on ? const Icon(Icons.check_rounded, color: AppColors.primary) : null,
                      onTap: () => Navigator.of(context).pop(v),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 日期选择（存 YYYY-MM-DD）。
class DateField extends StatelessWidget {
  const DateField({super.key, required this.label, required this.value, required this.onChanged, this.error, this.hint, this.fieldKey});
  final String label;
  final String? value;
  final ValueChanged<String> onChanged;
  final String? error;
  final String? hint;
  final Key? fieldKey;

  static String format(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final current = DateTime.tryParse(value ?? '');
    return FieldShell(
      label: label,
      error: error,
      hint: hint,
      child: InkWell(
        key: fieldKey,
        borderRadius: BorderRadius.circular(AppShape.inputRadius),
        onTap: () async {
          FocusScope.of(context).unfocus();
          final now = DateTime.now();
          final d = await showDatePicker(
            context: context,
            initialDate: current ?? DateTime(now.year - 30, 1, 1),
            firstDate: DateTime(now.year - 120),
            lastDate: now,
            initialEntryMode: DatePickerEntryMode.calendar,
          );
          if (d != null) onChanged(format(d));
        },
        child: Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: _boxDecoration(error != null),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value?.isNotEmpty == true ? value! : 'YYYY-MM-DD',
                  style: TextStyle(fontSize: 16, color: value?.isNotEmpty == true ? AppColors.text : AppColors.faint),
                ),
              ),
              const Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.faint),
            ],
          ),
        ),
      ),
    );
  }
}

/// 是 / 否（原型 .yn）。
class YesNo extends StatelessWidget {
  const YesNo({super.key, required this.value, required this.onChanged, this.yes = 'Yes', this.no = 'No', this.keyPrefix});
  final bool? value;
  final ValueChanged<bool> onChanged;
  final String yes;
  final String no;
  final String? keyPrefix;

  @override
  Widget build(BuildContext context) {
    Widget btn(bool v, String label) {
      final on = value == v;
      return Expanded(
        child: InkWell(
          key: keyPrefix == null ? null : Key('$keyPrefix.${v ? 'yes' : 'no'}'),
          borderRadius: BorderRadius.circular(10),
          onTap: () => onChanged(v),
          child: Container(
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: on ? AppColors.primaryWeak : AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: on ? AppColors.primary : AppColors.line),
            ),
            child: Text(
              label,
              style: TextStyle(fontWeight: FontWeight.w600, color: on ? AppColors.primary2 : AppColors.text),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(children: [btn(true, yes), const SizedBox(width: 8), btn(false, no)]),
    );
  }
}

/// 勾选行（原型 .check）。
class CheckRow extends StatelessWidget {
  const CheckRow({super.key, required this.value, required this.onChanged, required this.child, this.error});
  final bool value;
  final ValueChanged<bool> onChanged;
  final Widget child;
  final String? error;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      InkWell(
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 36,
                height: 36,
                child: Checkbox(value: value, onChanged: (v) => onChanged(v ?? false)),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: DefaultTextStyle.merge(style: const TextStyle(fontSize: 14), child: child),
                ),
              ),
            ],
          ),
        ),
      ),
      if (error != null)
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 6),
          child: Text(error!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
        ),
    ],
  );
}

/// 多选胶囊（原型 .chip）。
class ChipToggle extends StatelessWidget {
  const ChipToggle({super.key, required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(16),
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: selected ? AppColors.primaryWeak : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: selected ? AppColors.primary : AppColors.line),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          color: selected ? AppColors.primary : AppColors.text,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    ),
  );
}

/// 两列字段（原型 C.two），顶部对齐。
class TwoColumns extends StatelessWidget {
  const TwoColumns({super.key, required this.left, required this.right});
  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(child: left),
      const SizedBox(width: 10),
      Expanded(child: right),
    ],
  );
}

/// 键值行（原型 .kv）。
class KvRow extends StatelessWidget {
  const KvRow(this.k, this.v, {super.key, this.valueKey});
  final String k;
  final String v;
  final Key? valueKey;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 键与值都可换行，避免长英文键名溢出
        Flexible(flex: 5, child: Text(k, style: const TextStyle(fontSize: 14, color: AppColors.muted))),
        const SizedBox(width: 12),
        Expanded(
          flex: 6,
          child: Text(v, key: valueKey, textAlign: TextAlign.right, style: const TextStyle(fontSize: 14)),
        ),
      ],
    ),
  );
}

/// 徽标（原型 .badge）。
enum BadgeKind { neutral, ok, warn, danger, info }

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.label, {super.key, this.kind = BadgeKind.neutral});
  final String label;
  final BadgeKind kind;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (kind) {
      BadgeKind.neutral => (AppColors.surface2, AppColors.muted),
      BadgeKind.ok => (AppColors.primaryWeak, AppColors.primary2),
      BadgeKind.warn => (AppColors.warnWeak, AppColors.warn),
      BadgeKind.danger => (AppColors.dangerWeak, AppColors.danger),
      BadgeKind.info => (AppColors.infoWeak, AppColors.accent),
    };
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(11)),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}

/// 列表行（原型 .li）。
class ListRow extends StatelessWidget {
  const ListRow({super.key, required this.icon, required this.title, this.subtitle, this.onTap, this.trailing});
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 15)),
                if (subtitle != null) Text(subtitle!, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    ),
  );
}

/// 分组列表容器（原型 .list）。
class ListGroup extends StatelessWidget {
  const ListGroup({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppShape.radius), boxShadow: AppShape.shadow),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        for (var i = 0; i < children.length; i++) ...[if (i > 0) const Divider(height: 1, color: AppColors.line), children[i]],
      ],
    ),
  );
}

/// 小节标题（原型 .sec-title）。
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 18, 2, 10),
    child: Row(
      children: [
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        ),
        ?trailing,
      ],
    ),
  );
}
