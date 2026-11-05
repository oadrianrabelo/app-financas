import 'package:flutter/material.dart';

import '../../core/dates.dart';
import '../../core/money.dart';
import '../../data/app_data.dart';
import '../../data/database.dart';
import '../widgets/common.dart';
import '../widgets/entry_form.dart';

class EntriesPage extends StatefulWidget {
  const EntriesPage({super.key});

  @override
  State<EntriesPage> createState() => _EntriesPageState();
}

class _EntriesPageState extends State<EntriesPage> {
  String _month = monthOf(today());
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final data = scope.data;
    return ListenableBuilder(
      listenable: data,
      builder: (context, _) {
        final list = data
            .monthEntries(_month)
            .where((e) => e.description.toLowerCase().contains(_search.toLowerCase()))
            .toList();

        return PageBody(
          title: 'Lançamentos',
          trailing: MonthPicker(month: _month, onChanged: (m) => setState(() => _month = m)),
          fab: FloatingActionButton.extended(
            onPressed: () => showEntryForm(context),
            icon: const Icon(Icons.add),
            label: const Text('Novo'),
          ),
          children: [
            TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Buscar…',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  if (list.isEmpty) const ListTile(title: Text('Nada por aqui.')),
                  for (final e in list) _EntryTile(entry: e),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry});
  final Entry entry;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final data = scope.data;
    final e = entry;
    final cat = data.category(e.categoryId);
    final transfer = e.type == EntryType.transferencia;
    final (sign, color) = switch (e.type) {
      EntryType.receita => ('+', moneyColor(context, positive: true)),
      EntryType.despesa => ('−', moneyColor(context, positive: false)),
      EntryType.transferencia => ('⇄', null),
    };
    final subtitle = [
      formatDate(e.date),
      data.account(e.accountId)?.name ?? '—',
      if (transfer) '→ ${data.account(e.toAccountId)?.name ?? '—'}',
      if (!e.paid) 'pendente',
    ].join(' · ');

    return Opacity(
      opacity: e.paid ? 1 : 0.6,
      child: ListTile(
        leading: Text(transfer ? '🔁' : cat?.icon ?? '•', style: const TextStyle(fontSize: 22)),
        title: Text(
          e.description.isNotEmpty ? e.description : cat?.name ?? 'Sem descrição',
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(subtitle),
        onTap: () => showEntryForm(context, editing: e),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$sign ${formatBRL(e.amount)}',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color),
            ),
            PopupMenuButton<String>(
              onSelected: (action) async {
                if (action == 'pago') await scope.db.markPaid(e.id);
                if (action == 'excluir' && context.mounted && await confirm(context, 'Excluir este lançamento?')) {
                  await scope.db.softDelete(scope.db.entries, e.id);
                }
              },
              itemBuilder: (_) => [
                if (!e.paid) const PopupMenuItem(value: 'pago', child: Text('Marcar como pago')),
                const PopupMenuItem(value: 'excluir', child: Text('Excluir')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
