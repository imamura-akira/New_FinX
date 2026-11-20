import 'package:material_ui/material_ui.dart';

import '../../../app/theme.dart';
import '../../../core/format.dart';
import '../../../core/widgets/form_widgets.dart';
import '../../../core/widgets/widgets.dart';
import '../../market/presentation/market_widgets.dart';
import '../data/trading_api.dart';
import '../domain/trading_mode.dart';

/// 模拟盘品牌色：琥珀色系，与实盘的紫色明显区分（design/theme.md 第 7 节"模拟盘标识"）。
abstract final class PaperColors {
  static const fg = Color(0xFFB45309);
  static const bg = Color(0xFFFFF4E0);
  static const border = Color(0xFFF5C46B);
}

/// 模拟盘横幅：模拟模式下的每个页面顶部常驻（F15"明显的模拟盘标识"）。
class PaperBanner extends StatelessWidget {
  const PaperBanner({super.key, this.text = '模拟盘 · 虚拟资金，按演示行情撮合，不产生真实交易'});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('paper.banner'),
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: PaperColors.bg,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: PaperColors.border),
    ),
    child: Row(
      children: [
        const Icon(Icons.science_outlined, size: 18, color: PaperColors.fg),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: PaperColors.fg)),
        ),
      ],
    ),
  );
}

/// 标题旁的"模拟"角标。
class PaperBadge extends StatelessWidget {
  const PaperBadge({super.key});

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('paper.badge'),
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(color: PaperColors.fg, borderRadius: BorderRadius.circular(8)),
    child: const Text('模拟', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
  );
}

/// 标题 + 模拟角标。
Widget paperTitle(String title, bool paper) => paper
    ? Row(mainAxisSize: MainAxisSize.min, children: [Flexible(child: Text(title)), const SizedBox(width: 8), const PaperBadge()])
    : Text(title);

/// "实盘 / 模拟"切换（资产页、下单页）。切换写入 [TradingMode]。
class AccountModeSwitch extends StatelessWidget {
  const AccountModeSwitch({super.key, this.onChanged});
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: TradingMode.instance,
    builder: (context, paper, _) => Seg2<bool>(
      key: const Key('mode.switch'),
      items: const [(false, '实盘'), (true, '模拟盘')],
      value: paper,
      onChanged: (v) {
        if (v == TradingMode.instance.paper) return;
        TradingMode.instance.paper = v;
        onChanged?.call(v);
      },
    ),
  );
}

/// 资产页的模拟账户卡（只显示模拟数字，绝不混入 DW 资金）。
class PaperAccountCard extends StatelessWidget {
  const PaperAccountCard({super.key, required this.account, required this.onReset, this.hide = false});
  final PaperAccount account;
  final VoidCallback onReset;
  final bool hide;

  @override
  Widget build(BuildContext context) {
    final a = account;
    String v(double x) => hide ? '••••' : fmtUsd(x);
    final plColor = chgColor(a.totalPL);
    return Container(
      key: const Key('paper.hero'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: PaperColors.bg,
        borderRadius: BorderRadius.circular(AppShape.radius),
        border: Border.all(color: PaperColors.border, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const PaperBadge(),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('模拟账户总资产', style: TextStyle(fontSize: 13, color: PaperColors.fg, fontWeight: FontWeight.w600)),
              ),
              TextButton.icon(
                key: const Key('paper.reset'),
                onPressed: onReset,
                icon: const Icon(Icons.restart_alt_rounded, size: 18, color: PaperColors.fg),
                label: const Text('重置', style: TextStyle(color: PaperColors.fg)),
              ),
            ],
          ),
          Text(v(a.totalValue), key: const Key('paper.total'), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
          Text(
            hide ? '模拟盈亏 ••••' : '模拟盈亏 ${a.totalPL >= 0 ? '+' : ''}${fmtUsd(a.totalPL)}（${a.totalPLPct >= 0 ? '+' : ''}${a.totalPLPct.toStringAsFixed(2)}%）',
            key: const Key('paper.pl'),
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: plColor),
          ),
          const Divider(height: 22, color: PaperColors.border),
          KvRow('可用资金', v(a.buyingPower), valueKey: const Key('paper.buyingPower')),
          KvRow('持仓市值', v(a.positionsValue), valueKey: const Key('paper.positionsValue')),
          if (a.reservedCash > 0) KvRow('挂单冻结', v(a.reservedCash)),
          KvRow('初始资金', v(a.initialCash)),
        ],
      ),
    );
  }
}

/// 一键重置确认。
Future<bool> confirmPaperReset(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重置模拟账户？'),
        content: const Text('模拟资金将恢复为初始金额，模拟持仓与订单全部清空。此操作只影响模拟盘，不影响实盘账户。'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
          TextButton(key: const Key('paper.reset.confirm'), onPressed: () => Navigator.of(ctx).pop(true), child: const Text('重置')),
        ],
      ),
    ) ==
    true;
