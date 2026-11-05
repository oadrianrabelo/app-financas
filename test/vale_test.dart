import 'package:flutter_test/flutter_test.dart';
import 'package:livro_caixa/data/database.dart';
import 'package:livro_caixa/domain/finance.dart';
import 'package:livro_caixa/domain/vale.dart';

void main() {
  const vale = Account(
    id: 'va',
    createdAt: 0,
    updatedAt: 0,
    name: 'Vale',
    type: AccountType.vale,
    initialBalance: 0,
    archived: false,
    renewDay: 20,
    renewAmount: 60000,
  );
  Entry buy(String date, int amount, {String account = 'va'}) => Entry(
    id: date + amount.toString(),
    createdAt: 0,
    updatedAt: 0,
    type: EntryType.despesa,
    amount: amount,
    date: date,
    description: 'Mercado',
    accountId: account,
    paid: true,
  );

  test('vale renova no dia 20 e conta só o período atual', () {
    final entries = [
      buy('2026-10-25', 10000), // período anterior (20/10 a 19/11)
      buy('2026-11-20', 15000), // dia da renovação: conta no novo
      buy('2026-12-02', 5000),
      buy('2026-11-21', 9999, account: 'carteira'), // não é do vale
    ];
    final s = valeStatus(vale, entries, DateTime(2026, 12, 5));
    expect(s.periodStart, DateTime(2026, 11, 20));
    expect(s.nextRenewal, DateTime(2026, 12, 20));
    expect(s.spent, 20000);
    expect(s.left, 40000);
    expect(s.daysUntilRenewal(DateTime(2026, 12, 5)), 15);

    // Antes do dia 20: período começou no mês anterior.
    final before = valeStatus(vale, entries, DateTime(2026, 11, 10));
    expect(before.periodStart, DateTime(2026, 10, 20));
    expect(before.spent, 10000);
  });

  test('gastos com o vale não saem do Disponível', () {
    final s = monthSummary(
      [buy('2026-11-21', 15000), buy('2026-11-22', 3000, account: 'carteira')],
      const [],
      '2026-11',
      valeAccounts: {'va'},
    );
    expect(s.valeSpent, 15000);
    expect(s.expense, 3000);
  });
}
