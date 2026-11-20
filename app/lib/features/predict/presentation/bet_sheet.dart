import 'package:material_ui/material_ui.dart';

import '../../../app/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/widgets/form_widgets.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/l10n.dart';
import '../data/predict_api.dart';
import '../domain/predict_rules.dart';
import 'predict_widgets.dart';

/// 下注面板：输入积分 → 显示"若正确可得 X 分" → 确认。返回下注结果（取消为 null）。
Future<({int points, int potentialPayout})?> showBetSheet(
  BuildContext context, {
  required PredictApi api,
  required PredictMarket market,
  required String outcome,
  required int balance,
}) => showModalBottomSheet<({int points, int potentialPayout})>(
  context: context,
  useRootNavigator: true,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _BetSheet(api: api, market: market, outcome: outcome, balance: balance),
);

class _BetSheet extends StatefulWidget {
  const _BetSheet({required this.api, required this.market, required this.outcome, required this.balance});
  final PredictApi api;
  final PredictMarket market;
  final String outcome;
  final int balance;

  @override
  State<_BetSheet> createState() => _BetSheetState();
}

class _BetSheetState extends State<_BetSheet> {
  final _ctl = TextEditingController(text: '100');
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  PredictOutcome get _o => widget.outcome == 'NO' ? widget.market.no : widget.market.yes;

  String get _label => widget.market.isUpDown ? (widget.outcome == 'YES' ? t.predictUp : t.predictDown) : _o.label.text;

  Future<void> _confirm() async {
    final err = validateStake(_ctl.text, widget.balance);
    if (err != null) return setState(() => _error = err);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await widget.api.bet(widget.market.id, widget.outcome, int.parse(_ctl.text.trim()));
      if (mounted) {
        Navigator.of(context).pop((points: r.points, potentialPayout: r.potentialPayout));
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.fieldMap['stake'] ?? e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stake = int.tryParse(_ctl.text.trim()) ?? 0;
    final p = widget.market.prob(widget.outcome);
    final up = widget.outcome == 'YES';
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.market.isUpDown ? t.predictUpOrDownSymbol(widget.market.symbol ?? '') : widget.market.title.text,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: predictInk),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: up ? predictUpBg : predictDownBg, borderRadius: BorderRadius.circular(999)),
                child: Text(
                  t.predictYourPick(_label),
                  key: const Key('bet.pick'),
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: up ? AppColors.up : AppColors.down),
                ),
              ),
              const SizedBox(width: 8),
              Text(t.predictProbNow(_o.percent), style: const TextStyle(fontSize: 12, color: predictSub)),
            ],
          ),
          const SizedBox(height: 14),
          AppField(
            label: t.predictStake,
            fieldKey: const Key('bet.stake'),
            controller: _ctl,
            hint: t.predictStakeHint,
            keyboardType: TextInputType.number,
            error: _error,
            onChanged: (_) => setState(() => _error = null),
          ),
          Row(
            children: [
              for (final v in const [100, 500, 1000, 5000]) ...[
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChipToggle(
                    key: Key('bet.quick.$v'),
                    label: fmtPoints(v),
                    selected: stake == v,
                    onTap: () => setState(() {
                      _ctl.text = '$v';
                      _error = null;
                    }),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Text(t.predictAvailable(fmtPoints(widget.balance)), style: const TextStyle(fontSize: 12, color: predictSub)),
          const SizedBox(height: 6),
          Text(
            t.predictPotential(fmtPoints(stake >= predictMinStake ? predictPayout(stake, p) : 0)),
            key: const Key('bet.potential'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primary),
          ),
          const SizedBox(height: 6),
          Text(t.predictPricingNote, style: const TextStyle(fontSize: 11, color: predictFaint, height: 1.5)),
          const SizedBox(height: 14),
          AppButton(t.predictConfirm, key: const Key('bet.confirm'), loading: _busy, onPressed: _busy ? null : _confirm),
        ],
      ),
    );
  }
}
