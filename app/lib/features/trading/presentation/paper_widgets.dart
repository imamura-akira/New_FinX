import 'package:material_ui/material_ui.dart';

import '../../../app/theme.dart';
import '../../../core/format.dart';
import '../../../core/widgets/form_widgets.dart';
import '../../../core/widgets/widgets.dart';
import '../../market/presentation/market_widgets.dart';
import '../data/trading_api.dart';
import '../domain/trading_mode.dart';
import '../../../l10n/l10n.dart';

/// 模拟盘横幅：模拟模式下的每个页面顶部常驻（F15"明显的模拟盘标识"）。
class PaperBanner extends StatelessWidget {
  const PaperBanner({super.key, this.text});
  final String? text; // null = 默认横幅文案

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
        Icon(Icons.science_outlined, size: 18, color: PaperColors.fg),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text ?? t.paperPaperTradingVirtualFunds, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: PaperColors.fg)),
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
    child: Text(t.drawerPaper, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.onAccent)),
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
      items: [(false, t.drawerLive), (true, t.paperPaper)],
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
              Expanded(
                child: Text(t.paperPaperAccountTotalValue, style: TextStyle(fontSize: 13, color: PaperColors.fg, fontWeight: FontWeight.w600)),
              ),
              TextButton.icon(
                key: const Key('paper.reset'),
                onPressed: onReset,
                icon: Icon(Icons.restart_alt_rounded, size: 18, color: PaperColors.fg),
                label: Text(t.paperReset, style: TextStyle(color: PaperColors.fg)),
              ),
            ],
          ),
          Text(v(a.totalValue), key: const Key('paper.total'), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
          Text(
            hide
                ? t.paperPaperPL
                : t.paperPlValue('${a.totalPL >= 0 ? '+' : ''}${fmtUsd(a.totalPL)}', '${a.totalPLPct >= 0 ? '+' : ''}${a.totalPLPct.toStringAsFixed(2)}%'),
            key: const Key('paper.pl'),
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: plColor),
          ),
          Divider(height: 22, color: PaperColors.border),
          KvRow(t.paperAvailableFunds, v(a.buyingPower), valueKey: const Key('paper.buyingPower')),
          KvRow(t.drawerPositionsValue, v(a.positionsValue), valueKey: const Key('paper.positionsValue')),
          if (a.reservedCash > 0) KvRow(t.paperOnHoldForOrders, v(a.reservedCash)),
          KvRow(t.paperStartingBalance, v(a.initialCash)),
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
        title: Text(t.paperResetPaperAccount),
        content: Text(t.paperYourVirtualFundsWill),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(t.drawerCancel)),
          TextButton(key: const Key('paper.reset.confirm'), onPressed: () => Navigator.of(ctx).pop(true), child: Text(t.paperReset)),
        ],
      ),
    ) ==
    true;
