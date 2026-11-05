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

  test('outubro do caderno: disponível e sobra', () {
    Category cat(String id, CategorySection? section) => Category(
      id: id,
      createdAt: 0,
      updatedAt: 0,
      name: id,
      kind: CategoryKind.despesa,
      icon: '',
      color: 0,
      section: section,
    );
    final cats = [
      cat(dizimoCategoryId, CategorySection.primicias),
      cat(ofertaCategoryId, CategorySection.primicias),
      cat('fatura', CategorySection.cartao),
      cat('casa', CategorySection.casa),
      cat('pessoal', CategorySection.pessoal),
    ];
    final s = monthSummary(
      [
        tx(type: EntryType.receita, amount: 405301),
        tx(amount: 40530, cat: dizimoCategoryId, paid: false),
        tx(amount: 10132, cat: ofertaCategoryId),
        // Cartão: Nu Adrian, Nu Andressa, BB, PicPay
        for (final v in [166691, 34576, 4080, 4000]) tx(amount: v, cat: 'fatura'),
        // Casa: aluguel, internet, luz, academia, pão
        for (final v in [60000, 9990, 33842, 7000, 10000]) tx(amount: v, cat: 'casa'),
        tx(amount: 16314, cat: 'pessoal'), // Boticário
        tx(amount: 999, date: '2026-10-31', cat: 'casa'), // outro mês
        tx(type: EntryType.transferencia, amount: 7000, to: 'b'), // não conta
      ],
      cats,
      '2026-11',
    );
    expect(s.available, 354639); // 3.546,39
    expect(s.sectionTotal(CategorySection.cartao), 209347); // 2.093,47 (no caderno: 2.064,36)
    expect(s.sectionTotal(CategorySection.casa), 120832); // 1.208,32
    expect(s.left, 8146); // sobrou 81,46
    expect(s.unpaid, 40530); // dízimo ainda a entregar
  });
}
