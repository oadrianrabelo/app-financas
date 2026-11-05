import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livro_caixa/data/database.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('conta fixa aparece todo mês, sem duplicar, e a apagada não volta', () async {
    final first = await db.createRecurring(
      type: EntryType.despesa,
      description: 'Aluguel',
      amount: 60000,
      variable: false,
      day: 10,
      accountId: 'seed-conta-carteira',
      startMonth: '2026-11',
    );
    expect(first, 'rec-${(await db.watchRecurrings().first).single.id}-2026-11');

    await db.ensureRecurringEntries('2026-12');
    await db.ensureRecurringEntries('2026-12'); // de novo: não duplica
    var all = await db.watchAllEntries().first;
    expect(all.map((e) => e.date), unorderedEquals(['2026-11-10', '2026-12-10']));
    expect(all.every((e) => !e.paid), isTrue); // aparece para marcar ✓

    final dec = all.firstWhere((e) => e.date == '2026-12-10');
    await db.softDelete(db.entries, dec.id);
    await db.ensureRecurringEntries('2026-12');
    all = await db.watchAllEntries().first;
    expect(all, hasLength(1));
    expect((await db.ensureRecurringEntries('2026-10').then((_) => db.watchAllEntries().first)), hasLength(1));
  });

  test('valor que muda (luz) repete o do mês anterior', () async {
    final id = await db.createRecurring(
      type: EntryType.despesa,
      description: 'Luz',
      amount: 33537,
      variable: true,
      day: 15,
      accountId: 'seed-conta-carteira',
      startMonth: '2026-10',
    );
    final e = (await db.getEntry(id))!;
    await db.saveEntry(
      id: e.id,
      type: e.type,
      amount: 33842, // conta de outubro chegou
      date: e.date,
      description: e.description,
      accountId: e.accountId,
      paid: true,
    );
    await db.ensureRecurringEntries('2026-11');
    final nov = (await db.watchAllEntries().first).firstWhere((x) => x.date.startsWith('2026-11'));
    expect(nov.amount, 33842);
  });

  test('salário fixo nasce com dízimo pendente', () async {
    final id = await db.createRecurring(
      type: EntryType.receita,
      description: 'Salário',
      amount: 405301,
      variable: false,
      day: 5,
      accountId: 'seed-conta-carteira',
      startMonth: '2026-11',
    );
    expect((await db.getEntry(id))!.titheStatus, TitheStatus.pendente);
  });

  test('parcelas: uma por mês, com 1/2 e 2/2', () async {
    await db.saveInstallments(
      installment: 24428,
      count: 2,
      date: '2026-11-30',
      description: 'Perfume',
      accountId: 'seed-conta-carteira',
      firstPaid: false,
    );
    final all = (await db.watchAllEntries().first)..sort((a, b) => a.date.compareTo(b.date));
    expect(all.map((e) => e.date), ['2026-11-30', '2026-12-30']);
    expect(all.map((e) => e.installmentIndex), [1, 2]);
    expect(all.first.installmentGroup, all.last.installmentGroup);

    await db.saveInstallments(
      installment: 100,
      count: 2,
      date: '2026-01-31',
      description: 'X',
      accountId: 'seed-conta-carteira',
      firstPaid: true,
    );
    final feb = (await db.watchAllEntries().first).where((e) => e.description == 'X').map((e) => e.date);
    expect(feb, containsAll(['2026-01-31', '2026-02-28'])); // fevereiro não tem dia 31
  });

  test('pessoas da casa já existem e podem ser renomeadas', () async {
    expect((await db.watchPeople().first).map((p) => p.name), ['Adrian', 'Andressa']);
    await db.renamePerson('seed-pessoa-2', 'Dessa');
    expect((await db.watchPeople().first).last.name, 'Dessa');
  });
}
