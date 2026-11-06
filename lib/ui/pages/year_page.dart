import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/dates.dart';
import '../../core/money.dart';
import '../../data/app_data.dart';
import '../../data/database.dart';
import '../../domain/finance.dart';
import '../../domain/projection.dart';
import '../../domain/tithe.dart';
import '../kit/kit.dart';
import '../theme/paper.dart';
import '../widgets/common.dart';

const _monthShort = ['jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez'];

/// O ano de uma vez: os próximos meses, para onde foi o dinheiro e os negócios.
class YearPage extends StatefulWidget {
  const YearPage({super.key});

  @override
  State<YearPage> createState() => _YearPageState();
}

class _YearPageState extends State<YearPage> {
  int _year = DateTime.now().year;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final p = Paper.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([scope.data, scope.prefs]),
      builder: (context, _) {
        final data = scope.data;
        String m(int i) => '$_year-${(i + 1).toString().padLeft(2, '0')}';
        final months = [
          for (var i = 0; i < 12; i++)
            monthSummary(data.entries, data.categories, m(i), valeAccounts: data.valeAccountIds, cards: data.cards),
        ];
        final income = months.fold(0, (s, x) => s + x.income);
        final primicias = months.fold(0, (s, x) => s + x.tithe + x.offering);
        final expense = months.fold(0, (s, x) => s + x.expense);
        final saved = months.fold(0, (s, x) => s + x.savedTotal);
        final thisMonth = monthOf(today());
        final future = forecast(
          fromMonth: thisMonth,
          months: 6,
          entries: data.entries,
          recurrings: data.recurrings,
          categories: data.categories,
          valeAccounts: data.valeAccountIds,
          cards: data.cards,
          titheBp: scope.prefs.titheBp,
          offeringBp: scope.prefs.offeringBp,
        );

        return PageBody(
          title: 'Ano',
          subtitle: 'O que vem pela frente e para onde o dinheiro foi.',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              LcIconButton(LucideIcons.chevronLeft, onPressed: () => setState(() => _year--)),
              Text('$_year', style: p.mono(15, weight: FontWeight.w600)),
              LcIconButton(LucideIcons.chevronRight, onPressed: () => setState(() => _year++)),
            ],
          ),
          children: [
            LcGroup(
              title: 'PRÓXIMOS MESES',
              description:
                  'Entradas previstas menos o que já está comprometido: contas fixas, parcelas, faturas '
                  'e o dízimo e a oferta estimados.',
              children: [for (final f in future) _ForecastRow(f)],
            ),
            LcGroup(
              title: 'O ANO EM NÚMEROS',
              children: [
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        spacing: 22,
                        runSpacing: 12,
                        children: [
                          _Stat('Entrou', income),
                          _Stat('Dízimo e oferta', primicias),
                          _Stat('Gastos', expense),
                          _Stat('Guardado', saved, color: p.greenInk),
                          _Stat('Sobrou', income - primicias - expense - saved, color: p.greenInk),
                        ],
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        height: 160,
                        child: _YearChart(
                          months: months,
                          current: _year == DateTime.now().year ? DateTime.now().month - 1 : -1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _Legend(color: p.greenInk.withValues(alpha: 0.35), label: 'Entrou'),
                          const SizedBox(width: 14),
                          _Legend(color: p.ink, label: 'Saiu (gastos, dízimo, oferta)'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            _Categories(year: _year),
            _OfferingTrend(months: months, year: _year),
            _Projects(year: _year),
          ],
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, {this.color});
  final String label;
  final int value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = Paper.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: p.pencil, fontWeight: FontWeight.w600),
        ),
        Text(
          formatBRL(value),
          style: p.mono(16, weight: FontWeight.w700, color: color),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
      ),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(fontSize: 12, color: Paper.of(context).pencil)),
    ],
  );
}

class _ForecastRow extends StatelessWidget {
  const _ForecastRow(this.f);
  final MonthForecast f;

  @override
  Widget build(BuildContext context) {
    final p = Paper.of(context);
    final ratio = f.income <= 0 ? 1.0 : (f.committed / f.income).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  monthLabel(f.month),
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: p.ink),
                ),
              ),
              Text(
                f.free >= 0 ? 'livre ${formatBRL(f.free)}' : 'falta ${formatBRL(-f.free)}',
                style: p.mono(13.5, weight: FontWeight.w600, color: f.free >= 0 ? p.greenInk : p.redInk),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: Stack(
              children: [
                Container(height: 6, color: p.greenInk.withValues(alpha: 0.25)),
                FractionallySizedBox(
                  widthFactor: ratio,
                  child: Container(height: 6, color: f.free >= 0 ? p.ink : p.redInk),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'entra ${formatBRL(f.income)} · comprometido ${formatBRL(f.committed)}',
            style: TextStyle(fontSize: 12, color: p.pencil),
          ),
        ],
      ),
    );
  }
}

/// Barras do ano: entrou (claro) atrás, saiu (tinta) na frente.
class _YearChart extends StatelessWidget {
  const _YearChart({required this.months, required this.current});
  final List<MonthSummary> months;
  final int current;

  @override
  Widget build(BuildContext context) {
    final p = Paper.of(context);
    return CustomPaint(painter: _ChartPainter(months, current, p), child: const SizedBox.expand());
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter(this.months, this.current, this.p);
  final List<MonthSummary> months;
  final int current;
  final Paper p;

  @override
  void paint(Canvas canvas, Size size) {
    const labelH = 18.0;
    final h = size.height - labelH;
    final maxV = months.fold<int>(1, (m, s) => math.max(m, math.max(s.income, s.expense + s.tithe + s.offering)));
    final slot = size.width / 12;
    final barW = math.min(18.0, slot * 0.55);
    final base = Paint()..color = p.rule;
    canvas.drawLine(Offset(0, h), Offset(size.width, h), base);
    for (var i = 0; i < 12; i++) {
      final s = months[i];
      final x = slot * i + (slot - barW) / 2;
      final inH = h * s.income / maxV;
      final outH = h * (s.expense + s.tithe + s.offering) / maxV;
      final r = Radius.circular(barW / 3);
      canvas.drawRRect(
        RRect.fromRectAndCorners(Rect.fromLTWH(x, h - inH, barW, inH), topLeft: r, topRight: r),
        Paint()..color = p.greenInk.withValues(alpha: 0.3),
      );
      canvas.drawRRect(
        RRect.fromRectAndCorners(Rect.fromLTWH(x + barW * 0.2, h - outH, barW * 0.6, outH), topLeft: r, topRight: r),
        Paint()..color = p.ink.withValues(alpha: i == current ? 1 : 0.75),
      );
      final tp = TextPainter(
        text: TextSpan(
          text: _monthShort[i],
          style: TextStyle(
            fontFamily: p.uiFont,
            fontSize: 10.5,
            color: i == current ? p.ink : p.pencil,
            fontWeight: i == current ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(slot * i + (slot - tp.width) / 2, h + 4));
    }
  }

  @override
  bool shouldRepaint(_ChartPainter old) => true;
}

/// Para onde foi: gastos do ano por categoria.
class _Categories extends StatelessWidget {
  const _Categories({required this.year});
  final int year;

  @override
  Widget build(BuildContext context) {
    final data = AppScope.of(context).data;
    final p = Paper.of(context);
    final totals = <String?, int>{};
    for (final e in data.entries) {
      if (e.type != EntryType.despesa || !e.date.startsWith('$year')) continue;
      if (e.categoryId == dizimoCategoryId || e.categoryId == ofertaCategoryId || e.envelopeId != null) continue;
      totals.update(e.categoryId, (v) => v + e.amount, ifAbsent: () => e.amount);
    }
    final list = totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final top = list.take(8).toList();
    final maxV = top.isEmpty ? 1 : top.first.value;
    return LcGroup(
      title: 'PARA ONDE FOI',
      children: [
        if (top.isEmpty) const LcRow(title: 'Nenhum gasto neste ano'),
        for (final MapEntry(key: id, :value) in top)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(
              children: [
                SizedBox(width: 26, child: Text(data.category(id)?.icon ?? '•')),
                SizedBox(
                  width: 120,
                  child: Text(
                    data.category(id)?.name ?? 'Sem categoria',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13.5, color: p.ink),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: value / maxV,
                      minHeight: 6,
                      color: Color(data.category(id)?.color ?? 0xFF64748B),
                      backgroundColor: hairline(p),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(formatBRL(value), style: p.mono(13, weight: FontWeight.w600)),
              ],
            ),
          ),
      ],
    );
  }
}

/// A oferta ao longo do ano (em % das entradas), para ver ela crescendo.
class _OfferingTrend extends StatelessWidget {
  const _OfferingTrend({required this.months, required this.year});
  final List<MonthSummary> months;
  final int year;

  @override
  Widget build(BuildContext context) {
    final p = Paper.of(context);
    final items = [
      for (var i = 0; i < 12; i++)
        if (months[i].income > 0 && months[i].offering > 0) (i, bpOf(months[i].offering, months[i].income)),
    ];
    if (items.isEmpty) return const SizedBox.shrink();
    return LcGroup(
      title: 'OFERTA',
      description: 'Percentual das entradas ofertado em cada mês.',
      children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (i, bp) in items)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: hairline(p)),
                  ),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${_monthShort[i]}  ',
                          style: TextStyle(fontSize: 12.5, color: p.pencil),
                        ),
                        TextSpan(
                          text: formatBp(bp),
                          style: p.mono(13, weight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Negócios (ex.: Alfajor): vendas − custos = lucro.
class _Projects extends StatelessWidget {
  const _Projects({required this.year});
  final int year;

  @override
  Widget build(BuildContext context) {
    final data = AppScope.of(context).data;
    final p = Paper.of(context);
    final projectOf = {for (final c in data.categories) c.id: c.project};
    final thisMonth = monthOf(today());
    final stats = <String, ({int inY, int outY, int inM, int outM})>{};
    for (final c in data.categories) {
      if (c.project != null) stats.putIfAbsent(c.project!, () => (inY: 0, outY: 0, inM: 0, outM: 0));
    }
    for (final e in data.entries) {
      final proj = projectOf[e.categoryId];
      if (proj == null || e.deletedAt != null || !e.date.startsWith('$year')) continue;
      final s = stats[proj]!;
      final month = e.date.startsWith(thisMonth);
      stats[proj] = e.type == EntryType.receita
          ? (inY: s.inY + e.amount, outY: s.outY, inM: s.inM + (month ? e.amount : 0), outM: s.outM)
          : (inY: s.inY, outY: s.outY + e.amount, inM: s.inM, outM: s.outM + (month ? e.amount : 0));
    }
    if (stats.isEmpty) return const SizedBox.shrink();
    return LcGroup(
      title: 'NEGÓCIOS',
      description: 'Categorias marcadas com um negócio (Ajustes → Categorias). Lucro = vendas − custos.',
      children: [
        for (final MapEntry(key: name, value: s) in stats.entries)
          LcRow(
            leading: Text(name == 'Alfajor' ? '🍪' : '💼', style: const TextStyle(fontSize: 18)),
            title: name,
            subtitle: 'No ano: vendeu ${formatBRL(s.inY)} · custou ${formatBRL(s.outY)}',
            trailing: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  formatBRL(s.inY - s.outY),
                  style: p.mono(14, weight: FontWeight.w700, color: s.inY >= s.outY ? p.greenInk : p.redInk),
                ),
                Text('este mês ${formatBRL(s.inM - s.outM)}', style: TextStyle(fontSize: 11.5, color: p.pencil)),
              ],
            ),
          ),
      ],
    );
  }
}
