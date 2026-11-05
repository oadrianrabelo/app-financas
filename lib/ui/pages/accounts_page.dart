import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../../data/app_data.dart';
import '../../data/database.dart';
import '../../domain/finance.dart';
import '../../domain/vale.dart';
import '../widgets/common.dart';

const accountTypeLabels = {
  AccountType.corrente: '🏦 Conta corrente',
  AccountType.poupanca: '🐷 Poupança',
  AccountType.carteira: '👛 Carteira',
  AccountType.cartao: '💳 Cartão de crédito',
  AccountType.investimento: '📈 Investimento',
  AccountType.vale: '🍽️ Vale-alimentação',
};

class AccountsPage extends StatelessWidget {
  const AccountsPage({super.key});

  Future<void> _remove(BuildContext context, Account a) async {
    final scope = AppScope.of(context);
    final used = scope.data.entries.any((e) => e.accountId == a.id || e.toAccountId == a.id);
    if (used) {
      if (await confirm(context, '"${a.name}" tem lançamentos. Arquivar a conta em vez de excluir?')) {
        await scope.db.setAccountArchived(a.id, true);
      }
    } else if (await confirm(context, 'Excluir "${a.name}"?')) {
      await scope.db.softDelete(scope.db.accounts, a.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return ListenableBuilder(
      listenable: scope.data,
      builder: (context, _) => PageBody(
        title: 'Contas',
        fab: FloatingActionButton.extended(
          onPressed: () => showDialog(context: context, builder: (_) => const _NewAccountDialog()),
          icon: const Icon(Icons.add),
          label: const Text('Nova conta'),
        ),
        children: [
          Card(
            child: Column(
              children: [
                for (final a in scope.data.accounts)
                  Opacity(
                    opacity: a.archived ? 0.6 : 1,
                    child: ListTile(
                      title: Text(a.archived ? '${a.name} (arquivada)' : a.name),
                      subtitle: Text(
                        a.type == AccountType.vale
                            ? '${accountTypeLabels[a.type]} · renova dia ${a.renewDay} com ${formatBRL(a.renewAmount ?? 0)}'
                            : accountTypeLabels[a.type]!,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Builder(
                            builder: (context) {
                              // Vale: o que resta até a próxima renovação.
                              final balance = a.type == AccountType.vale
                                  ? valeStatus(a, scope.data.entries, DateTime.now()).left
                                  : accountBalance(a, scope.data.entries);
                              return Text(
                                formatBRL(balance),
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: balance < 0 ? moneyColor(context, positive: false) : null,
                                ),
                              );
                            },
                          ),
                          a.archived
                              ? IconButton(
                                  tooltip: 'Desarquivar',
                                  icon: const Icon(Icons.unarchive_outlined),
                                  onPressed: () => scope.db.setAccountArchived(a.id, false),
                                )
                              : IconButton(
                                  tooltip: 'Excluir / arquivar',
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () => _remove(context, a),
                                ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NewAccountDialog extends StatefulWidget {
  const _NewAccountDialog();

  @override
  State<_NewAccountDialog> createState() => _NewAccountDialogState();
}

class _NewAccountDialogState extends State<_NewAccountDialog> {
  final _name = TextEditingController();
  final _initial = TextEditingController();
  final _renewAmount = TextEditingController();
  final _renewDay = TextEditingController(text: '20');
  AccountType _type = AccountType.corrente;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nova conta'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Nome', hintText: 'Ex.: Nubank'),
          ),
          DropdownButtonFormField(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'Tipo'),
            items: [
              for (final MapEntry(:key, :value) in accountTypeLabels.entries)
                DropdownMenuItem(value: key, child: Text(value)),
            ],
            onChanged: (v) => setState(() => _type = v!),
          ),
          if (_type == AccountType.vale) ...[
            TextField(
              controller: _renewAmount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Valor que entra todo mês', prefixText: r'R$ '),
            ),
            TextField(
              controller: _renewDay,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Dia em que renova', hintText: '20'),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('O vale fica fora do Disponível. Lance as compras com ele para ver quanto resta.'),
            ),
          ] else
            TextField(
              controller: _initial,
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              decoration: const InputDecoration(labelText: 'Saldo inicial', prefixText: r'R$ '),
            ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () async {
            if (_name.text.trim().isEmpty) return;
            final vale = _type == AccountType.vale;
            await AppScope.of(context).db.addAccount(
              name: _name.text.trim(),
              type: _type,
              initialBalance: vale ? 0 : parseBRL(_initial.text) ?? 0,
              renewAmount: vale ? parseBRL(_renewAmount.text) ?? 0 : null,
              renewDay: vale ? (int.tryParse(_renewDay.text) ?? 20).clamp(1, 28) : null,
            );
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Adicionar'),
        ),
      ],
    );
  }
}
