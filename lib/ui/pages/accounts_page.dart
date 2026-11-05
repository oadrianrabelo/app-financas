import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../../data/app_data.dart';
import '../../data/database.dart';
import '../../domain/finance.dart';
import '../../domain/vale.dart';
import '../kit/kit.dart';
import '../theme/paper.dart';
import '../widgets/common.dart';
import '../widgets/editors.dart';

class AccountsPage extends StatelessWidget {
  const AccountsPage({super.key});

  Future<void> _remove(BuildContext context, Account a) async {
    final scope = AppScope.of(context);
    final used = scope.data.entries.any((e) => e.accountId == a.id || e.toAccountId == a.id);
    if (used) {
      if (await lcConfirm(
        context,
        '"${a.name}" tem lançamentos, então não dá para excluir. Arquivar esconde a conta dos formulários, '
        'mas mantém o histórico.',
        confirm: 'Arquivar',
        title: 'Arquivar conta?',
      )) {
        await scope.db.setAccountArchived(a.id, true);
      }
    } else if (await lcConfirm(
      context,
      'Essa conta não tem lançamentos.',
      confirm: 'Excluir',
      danger: true,
      title: 'Excluir "${a.name}"?',
    )) {
      await scope.db.softDelete(scope.db.accounts, a.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final p = Paper.of(context);
    return ListenableBuilder(
      listenable: scope.data,
      builder: (context, _) {
        final data = scope.data;
        final now = DateTime.now();
        int balanceOf(Account a) =>
            a.type == AccountType.vale ? valeStatus(a, data.entries, now).left : accountBalance(a, data.entries);
        final active = data.accounts.where((a) => !a.archived).toList();
        final archived = data.accounts.where((a) => a.archived).toList();
        final total = active.where((a) => a.type != AccountType.vale).fold(0, (s, a) => s + balanceOf(a));

        Widget row(Account a) {
          final balance = balanceOf(a);
          final vale = a.type == AccountType.vale;
          return LcRow(
            dim: a.archived,
            leading: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: p.ink.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(8)),
              child: Icon(accountTypeIcons[a.type], size: 16, color: p.ink),
            ),
            title: a.name,
            subtitle: vale
                ? 'Vale · renova dia ${a.renewDay} com ${formatBRL(a.renewAmount ?? 0)}'
                : accountTypeLabels[a.type],
            onTap: () => showAccountEditor(context, editing: a),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      formatBRL(balance),
                      style: p.mono(14, weight: FontWeight.w600, color: balance < 0 ? p.redInk : p.ink),
                    ),
                    if (vale) Text('restam', style: TextStyle(fontSize: 11.5, color: p.pencil)),
                  ],
                ),
                const SizedBox(width: 4),
                a.archived
                    ? LcIconButton(
                        LucideIcons.archiveRestore,
                        tooltip: 'Desarquivar',
                        size: 15,
                        onPressed: () => scope.db.setAccountArchived(a.id, false),
                      )
                    : LcIconButton(
                        LucideIcons.archive,
                        tooltip: 'Arquivar ou excluir',
                        size: 15,
                        onPressed: () => _remove(context, a),
                      ),
              ],
            ),
          );
        }

        return PageBody(
          title: 'Contas',
          subtitle: 'Onde o dinheiro está. Toque numa conta para editar.',
          trailing: LcButton(
            'Nova conta',
            icon: LucideIcons.plus,
            kind: LcButtonKind.secondary,
            onPressed: () => showAccountEditor(context),
          ),
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              margin: const EdgeInsets.only(bottom: 22),
              decoration: BoxDecoration(
                color: p.paper,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: hairline(p)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Saldo total',
                    style: TextStyle(fontSize: 13, color: p.pencil, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatBRL(total),
                    style: p.mono(30, weight: FontWeight.w700, color: total < 0 ? p.redInk : p.ink),
                  ),
                  Text('sem contar o vale', style: TextStyle(fontSize: 12, color: p.pencil)),
                ],
              ),
            ),
            LcGroup(title: 'CONTAS', children: [for (final a in active) row(a)]),
            if (archived.isNotEmpty) LcGroup(title: 'ARQUIVADAS', children: [for (final a in archived) row(a)]),
          ],
        );
      },
    );
  }
}
