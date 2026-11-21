import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme.dart';
import '../domain/instruments.dart';
import '../../../l10n/l10n.dart';

/// F22-b P-09 搜索页：在标的池（股票与 ETF）中按代码或名称搜索（不区分大小写；代码前缀匹配优先），点击进入个股页 P-10。
/// 输入为空时列出全部标的。纯本地目录检索，不发请求。
List<InstrumentInfo> searchInstruments(String query) {
  final q = query.trim().toUpperCase();
  final pool = [for (final i in instruments) if (i.type == 'STOCK' || i.type == 'ETF') i];
  if (q.isEmpty) return pool;
  int rank(InstrumentInfo i) => i.symbol == q ? 0 : (i.symbol.startsWith(q) ? 1 : (i.symbol.contains(q) ? 2 : 3));
  final hits = [for (final i in pool) if (i.symbol.contains(q) || i.name.toUpperCase().contains(q)) i];
  hits.sort((a, b) => rank(a) != rank(b) ? rank(a) - rank(b) : a.symbol.compareTo(b.symbol));
  return hits;
}

class MarketSearchPage extends StatefulWidget {
  const MarketSearchPage({super.key});

  @override
  State<MarketSearchPage> createState() => _MarketSearchPageState();
}

class _MarketSearchPageState extends State<MarketSearchPage> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hits = searchInstruments(_c.text);
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(key: const Key('nav.back'), onPressed: () => context.pop()),
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: TextField(
            key: const Key('search.input'),
            controller: _c,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: t.marketSearchHint,
              prefixIcon: Icon(Icons.search_rounded, color: AppColors.sub),
              isDense: true,
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide(color: AppColors.border)),
            ),
          ),
        ),
      ),
      body: hits.isEmpty
          ? Center(
              child: Text(t.marketSearchNoResults, key: const Key('search.empty'), style: TextStyle(color: AppColors.muted)),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: hits.length,
              separatorBuilder: (_, _) => Divider(height: 1, color: AppColors.divider, indent: 16),
              itemBuilder: (context, i) {
                final h = hits[i];
                return ListTile(
                  key: Key('search.hit.${h.symbol}'),
                  title: Text(h.symbol, style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink)),
                  subtitle: Text(h.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.sub)),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: AppColors.pill, borderRadius: BorderRadius.circular(999)),
                    child: Text(h.type == 'ETF' ? 'ETF' : t.assetStock, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.sub)),
                  ),
                  onTap: () => context.push('/market/${h.symbol}'),
                );
              },
            ),
    );
  }
}
