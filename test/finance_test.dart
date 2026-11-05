import 'package:flutter_test/flutter_test.dart';
import 'package:livro_caixa/data/database.dart';
import 'package:livro_caixa/domain/finance.dart';

Account acc(String id, [int initial = 0]) => Account(
  id: id,
  createdAt: 0,
  updatedAt: 0,
  name: id,
  type: AccountType.corrente,
  initialBalance: initial,
  archived: false,
);

var _n = 0;
Entry tx({
  EntryType type = EntryType.despesa,
  required int amount,
  String date = '2026-11-01',
  String? to,
  String? cat,
  bool paid = true,
  int? deletedAt,
}) => Entry(
  id: '${_n++}',
  createdAt: 0,
  updatedAt: 0,
  deletedAt: deletedAt,
  type: type,
  amount: amount,
  date: date,
  description: '',
  accountId: 'a',
  toAccountId: to,
  categoryId: cat,
  paid: paid,
);

void main() {
  test('saldo: receitas, despesas e transferências', () {
    final list = [
      tx(type: EntryType.receita, amount: 500000),
      tx(amount: 12050),
      tx(type: EntryType.transferencia, amount: 100000, to: 'b'),
      tx(amount: 999, paid: false), // não pago: ignora
      tx(amount: 999, deletedAt: 1), // apagado: ignora
    ];
    expect(accountBalance(acc('a', 1000), list), 1000 + 500000 - 12050 - 100000);
    expect(accountBalance(acc('b'), list), 100000);
  });

  test('resumo do mês agrupa por categoria', () {
    final s = monthSummary([
      tx(type: EntryType.receita, amount: 300000),
      tx(amount: 1000, cat: 'mercado'),
      tx(amount: 2000, cat: 'mercado', paid: false),
      tx(amount: 5000, date: '2026-10-31'), // outro mês
      tx(type: EntryType.transferencia, amount: 7000, to: 'b'),
    ], '2026-11');
    expect(s.income, 300000);
    expect(s.expense, 3000);
    expect(s.balance, 297000);
    expect(s.pending, 2000);
    expect(s.byCategory['mercado'], 3000);
  });
}
