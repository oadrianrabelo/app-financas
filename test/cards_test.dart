import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livro_caixa/data/database.dart';
import 'package:livro_caixa/domain/cards.dart';
import 'package:livro_caixa/domain/envelopes.dart';
import 'package:livro_caixa/domain/finance.dart';
import 'package:livro_caixa/domain/projection.dart';

Account card({int? closing = 3, int? due = 10}) => Account(
  id: 'nu',
  createdAt: 0,
  updatedAt: 0,
  name: 'Nu Adrian',
  type: AccountType.cartao,
  initialBalance: 0,
  archived: false,
  closingDay: closing,
  dueDay: due,
);

Entry buy(String date, int amount, {String account = 'nu', bool paid = false}) => Entry(
  id: '$date$amount',
  createdAt: 0,
  updatedAt: 0,
  type: EntryType.despesa,
  amount: amount,
  date: date,
  description: 'compra',
  accountId: account,
  paid: paid,
);

void main() {
  test('compra até o fechamento vence no mês; depois, no seguinte', () {
    final c = card(); // fecha dia 3, vence dia 10
    expect(invoiceDueMonth(c, '2026-11-02'), '2026-11');
    expect(invoiceDueMonth(c, '2026-11-03'), '2026-11');
    expect(invoiceDueMonth(c, '2026-11-04'), '2026-12');
    // Vence antes do fechamento (fecha 28, vence 5): vence no mês seguinte ao fechamento.
    final c2 = card(closing: 28, due: 5);
    expect(invoiceDueMonth(c2, '2026-11-20'), '2026-12');
    expect(invoiceDueMonth(c2, '2026-11-29'), '2027-01');
  });

  test('fatura soma as compras e entra no Cartão do mês do vencimento', () {
    final entries = [buy('2026-10-20', 10000), buy('2026-11-02', 5000), buy('2026-11-05', 7000)];
    final s = monthSummary(entries, const [], '2026-11', cards: [card()]);
    expect(s.invoices.single.total, 15000); // 20/10 e 02/11 (fecha dia 3)
    expect(s.sectionTotal(CategorySection.cartao), 15000);
    expect(s.expense, 15000);
    expect(s.invoices.single.dueDate, '2026-11-10');
    final dec = monthSummary(entries, const [], '2026-12', cards: [card()]);
    expect(dec.invoices.single.total, 7000);
  });

  test('envelopes: guardar tira do disponível; tirar volta sem dízimo', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final id = await db.addEnvelope(name: 'Férias', initialBalance: 150000);
    final env = (await db.watchEnvelopes().first).single;
    expect(env.id, id);
    await db.moveEnvelope(
      envelope: env,
      amount: 8146,
      save: true,
      date: '2026-11-30',
      accountId: 'seed-conta-carteira',
    );
    await db.moveEnvelope(
      envelope: env,
      amount: 20000,
      save: false,
      date: '2026-12-10',
      accountId: 'seed-conta-carteira',
    );
    final entries = await db.watchAllEntries().first;
    expect(envelopeBalance(env, entries), 150000 + 8146 - 20000);
    final nov = monthSummary(entries, await db.watchCategories().first, '2026-11');
    expect(nov.savedTotal, 8146);
    expect(nov.expense, 0); // guardar não é gasto
    expect(nov.left, -8146);
    final withdrawal = entries.firstWhere((e) => e.type == EntryType.receita);
    expect(withdrawal.titheStatus, TitheStatus.isento);
  });

  test('a receber: quando volta, vira entrada sem dízimo', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.addReceivable(description: 'Adiantamento emprestado', amount: 120000, dueDate: '2026-12-30');
    final r = (await db.watchReceivables().first).single;
    await db.receive(r, accountId: 'seed-conta-carteira', date: '2026-12-30');
    final e = (await db.watchAllEntries().first).single;
    expect(e.amount, 120000);
    expect(e.titheStatus, TitheStatus.isento);
    expect((await db.watchReceivables().first).single.receivedEntryId, e.id);
  });

  test('próximos meses: contas fixas ainda não lançadas e parcelas entram', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.createRecurring(
      type: EntryType.receita,
      description: 'Salário',
      amount: 405301,
      variable: false,
      day: 5,
      accountId: 'seed-conta-carteira',
      startMonth: '2026-11',
    );
    await db.createRecurring(
      type: EntryType.despesa,
      description: 'Aluguel',
      amount: 60000,
      variable: false,
      day: 10,
      accountId: 'seed-conta-carteira',
      startMonth: '2026-11',
    );
    await db.saveInstallments(
      installment: 24428,
      count: 2,
      date: '2026-11-30',
      description: 'Perfume',
      accountId: 'seed-conta-carteira',
      firstPaid: false,
    );
    final f = forecast(
      fromMonth: '2026-12',
      months: 2,
      entries: await db.watchAllEntries().first,
      recurrings: await db.watchRecurrings().first,
      categories: await db.watchCategories().first,
      valeAccounts: const {},
      cards: const [],
      titheBp: 1000,
      offeringBp: 250,
    );
    expect(f[0].income, 405301);
    // dezembro: aluguel + parcela 2/2 + dízimo/oferta estimados
    expect(f[0].committed, 60000 + 24428 + 40530 + 10132);
    expect(f[1].committed, 60000 + 40530 + 10132); // janeiro: sem parcela
  });
}
