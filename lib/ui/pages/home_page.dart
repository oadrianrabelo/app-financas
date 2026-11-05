import 'package:flutter/material.dart';

import '../../core/dates.dart';
import '../../core/money.dart';
import '../../data/app_data.dart';
import '../../domain/finance.dart';
import '../widgets/common.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _month = monthOf(today());

  @override
  Widget build(BuildContext context) {
    final data = AppScope.of(context).data;
    return ListenableBuilder(
      listenable: data,
      builder: (context, _) {
        final s = monthSummary(data.entries, _month);
        final total = data.accounts.fold(0, (sum, a) => sum + accountBalance(a, data.entries));
        final byCat = s.byCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        final max = byCat.isEmpty ? 1 : byCat.first.value;
        final text = Theme.of(context).textTheme;

        return PageBody(
          title: 'Início',
          trailing: MonthPicker(month: _month, onChanged: (m) => setState(() => _month = m)),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Saldo total nas contas', style: text.bodyMedium),
                    Text(
                      formatBRL(total),
                      style: text.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: total < 0 ? moneyColor(context, positive: false) : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            LayoutBuilder(
              builder: (context, c) {
                final cols = c.maxWidth >= 600 ? 4 : 2;
                final w = (c.maxWidth - (cols - 1) * 8) / cols;
                Widget stat(String label, int value, Color? color) => SizedBox(
                  width: w,
                  child: Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label, style: text.labelMedium),
                          FittedBox(
                            child: Text(
                              formatBRL(value),
                              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: color),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      stat('Receitas', s.income, moneyColor(context, positive: true)),
                      stat('Despesas', s.expense, moneyColor(context, positive: false)),
                      stat('Resultado', s.balance, moneyColor(context, positive: s.balance >= 0)),
                      stat('A pagar', s.pending, null),
                    ],
                  ),
                );
              },
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Gastos por categoria', style: text.titleMedium),
                    const SizedBox(height: 8),
                    if (byCat.isEmpty) const Text('Nenhuma despesa neste mês.'),
                    for (final MapEntry(key: id, :value) in byCat)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(switch (data.category(id)) {
                                final c? => '${c.icon} ${c.name}',
                                null => 'Sem categoria',
                              }, overflow: TextOverflow.ellipsis),
                            ),
                            Expanded(
                              flex: 3,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(99),
                                child: LinearProgressIndicator(
                                  value: value / max,
                                  minHeight: 8,
                                  color: Color(data.category(id)?.color ?? 0xFF64748B),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(formatBRL(value), style: const TextStyle(fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
