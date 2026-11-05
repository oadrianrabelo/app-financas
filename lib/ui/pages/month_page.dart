import 'package:flutter/material.dart';

import '../../core/dates.dart';
import '../../core/money.dart';
import '../../data/app_data.dart';
import '../../data/database.dart';
import '../../domain/finance.dart';
import '../../domain/tithe.dart';
import '../theme/paper.dart';
import '../widgets/entry_form.dart';
import '../widgets/ledger.dart';
import '../widgets/tithe_dialog.dart';

const _sectionNames = {
  CategorySection.cartao: 'Cartão',
  CategorySection.casa: 'Casa',
  CategorySection.pessoal: 'Pessoal',
  CategorySection.outros: 'Outros',
};

/// A página do mês, como no caderno. Arraste para o lado para virar a página.
class MonthPage extends StatefulWidget {
  const MonthPage({super.key});

  @override
  State<MonthPage> createState() => _MonthPageState();
}

class _MonthPageState extends State<MonthPage> {
  static const _origin = 600; // página do mês atual
  final _thisMonth = monthOf(today());
  final _controller = PageController(initialPage: _origin);
  late String _month = _thisMonth;

  String _monthAt(int index) => addMonths(_thisMonth, index - _origin);

  void _go(int delta) => _controller.animateToPage(
    (_controller.page?.round() ?? _origin) + delta,
    duration: const Duration(milliseconds: 280),
    curve: Curves.easeOut,
  );

  @override
  Widget build(BuildContext context) {
    final p = Paper.of(context);
    return Scaffold(
      backgroundColor: p.paperShade,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showEntryForm(context, date: _defaultDate(_month)),
        icon: const Icon(Icons.edit),
        label: Text('Lançar', style: p.hand(20, color: Theme.of(context).colorScheme.onPrimaryContainer)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(tooltip: 'Mês anterior', icon: const Icon(Icons.chevron_left), onPressed: () => _go(-1)),
                SizedBox(
                  width: 200,
                  child: Text(
                    monthLabel(_month),
                    textAlign: TextAlign.center,
                    style: p.hand(22, color: p.pencil),
                  ),
                ),
                IconButton(tooltip: 'Próximo mês', icon: const Icon(Icons.chevron_right), onPressed: () => _go(1)),
                if (_month != _thisMonth)
                  TextButton(
                    onPressed: () => _controller.animateToPage(
                      _origin,
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOut,
                    ),
                    child: const Text('Hoje'),
                  ),
              ],
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _controller,
              onPageChanged: (i) => setState(() => _month = _monthAt(i)),
              itemBuilder: (context, i) => _MonthSheet(month: _monthAt(i)),
            ),
          ),
        ],
      ),
    );
  }
}

String _defaultDate(String month) => month == monthOf(today()) ? today() : '$month-01';

class _MonthSheet extends StatelessWidget {
  const _MonthSheet({required this.month});
  final String month;

  @override
  Widget build(BuildContext context) {
    final data = AppScope.of(context).data;
    return ListenableBuilder(
      listenable: data,
      builder: (context, _) {
        final s = monthSummary(data.entries, data.categories, month);
        final pending = pendingTithe(data.entries, month: month);
        return LayoutBuilder(
          builder: (context, c) {
            final left = _incomeBlock(context, s, pending);
            final right = _expenseBlock(context, s);
            final minHeight = c.maxHeight - 24;
            if (c.maxWidth >= 1000) {
              // Livro aberto: entradas à esquerda, gastos à direita.
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 96),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: LedgerSheet(minHeight: minHeight, children: left),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: LedgerSheet(minHeight: minHeight, children: right),
                    ),
                  ],
                ),
              );
            }
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 96),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: LedgerSheet(minHeight: minHeight, children: [...left, const LedgerGap(), ...right]),
                ),
              ),
            );
          },
        );
      },
    );
  }

  List<Widget> _incomeBlock(BuildContext context, MonthSummary s, List<Entry> pending) {
    final scope = AppScope.of(context);
    final p = Paper.of(context);
    final data = scope.data;
    String labelOf(Entry e) =>
        e.description.isNotEmpty ? e.description : data.category(e.categoryId)?.name ?? 'Entrada';
    final pendingTotal = pending.fold(0, (sum, e) => sum + e.amount);

    return [
      LedgerHeading(monthLabel(month).split(' de ').first, big: true),
      LedgerHeading(
        'Entradas',
        trailing: IconButton(
          tooltip: 'Nova entrada',
          icon: Icon(Icons.add, color: p.pencil),
          onPressed: () => showEntryForm(context, type: EntryType.receita, date: _defaultDate(month)),
        ),
      ),
      if (s.incomes.isEmpty) LedgerRow(label: 'Nenhuma entrada ainda', color: p.pencil),
      for (final e in s.incomes)
        LedgerRow(
          label: labelOf(e),
          value: e.amount,
          note: switch (e.titheStatus) {
            TitheStatus.pendente => 'dízimo pendente',
            TitheStatus.isento => 'sem dízimo',
            _ => null,
          },
          onTap: () => showEntryForm(context, editing: e),
        ),
      if (pending.isNotEmpty)
        StickyNote(
          text: 'Dízimo a separar de ${formatBRL(pendingTotal)}',
          action: TextButton(
            onPressed: () => showTitheDialog(context, incomes: pending),
            child: Text(
              'Separar agora',
              style: p.hand(20, color: p.redInk, weight: FontWeight.w700),
            ),
          ),
        ),
      const LedgerGap(),
      if (s.tithes.isEmpty && s.income > 0) LedgerRow(label: 'Dízimo', note: 'não separado', color: p.pencil),
      for (final e in [...s.tithes, ...s.offerings])
        LedgerRow(
          label: e.categoryId == dizimoCategoryId ? 'Dízimo' : 'Oferta',
          note: [if (e.percentBp != null) formatBp(e.percentBp!), if (!e.paid) 'a entregar'].join(' · '),
          value: e.amount,
          sign: '−',
          checked: e.paid,
          onCheck: () => scope.db.setPaid(e.id, !e.paid),
          onTap: () => showEntryForm(context, editing: e),
        ),
      LedgerRow(label: 'Disponível', value: s.available, color: p.redInk, bold: true),
    ];
  }

  List<Widget> _expenseBlock(BuildContext context, MonthSummary s) {
    final scope = AppScope.of(context);
    final p = Paper.of(context);
    final data = scope.data;
    final hasAny = s.sections.values.any((l) => l.isNotEmpty);

    return [
      if (!hasAny) ...[LedgerHeading('Gastos'), LedgerRow(label: 'Nenhum gasto ainda', color: p.pencil)],
      for (final MapEntry(key: section, value: list) in s.sections.entries)
        if (list.isNotEmpty) ...[
          LedgerHeading(
            _sectionNames[section]!,
            trailing: Text(formatBRL(s.sectionTotal(section)), style: p.mono(15, weight: FontWeight.w700)),
          ),
          for (final e in list)
            LedgerRow(
              label: e.description.isNotEmpty ? e.description : data.category(e.categoryId)?.name ?? 'Gasto',
              value: e.amount,
              checked: e.paid,
              onCheck: () => scope.db.setPaid(e.id, !e.paid),
              onTap: () => showEntryForm(context, editing: e),
            ),
        ],
      const LedgerGap(),
      LedgerRow(
        label: s.left >= 0 ? 'Sobrou' : 'Faltou',
        value: s.left.abs(),
        color: s.left >= 0 ? p.greenInk : p.redInk,
        bold: true,
      ),
      if (s.unpaid > 0) LedgerRow(label: 'Ainda a pagar', value: s.unpaid, color: p.pencil),
    ];
  }
}
