import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livro_caixa/data/database.dart';
import 'package:livro_caixa/domain/finance.dart';
import 'package:livro_caixa/domain/tithe.dart';

void main() {
  test('separar dízimo e oferta: lança, marca a entrada e fecha o disponível', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final salario = await db.saveEntry(
      type: EntryType.receita,
      amount: 405301,
      date: '2026-11-05',
      description: 'Salário',
      accountId: 'seed-conta-carteira',
      categoryId: 'seed-cat-salario',
      paid: true,
      titheStatus: TitheStatus.pendente,
    );
    await db.saveEntry(
      type: EntryType.receita,
      amount: 5000,
      date: '2026-11-06',
      description: 'Empréstimo voltou',
      accountId: 'seed-conta-carteira',
      paid: true,
      titheStatus: TitheStatus.isento,
    );

    var entries = await db.watchAllEntries().first;
    final pending = pendingTithe(entries, month: '2026-11');
    expect(pending.map((e) => e.id), [salario]); // o isento não entra

    final s = TitheSuggestion(base: 405301, titheBp: 1000, offeringBp: 250);
    await db.separateTithe(incomes: pending, tithe: s.tithe, titheBp: 1000, offering: s.offering, offeringBp: 250);

    entries = await db.watchAllEntries().first;
    expect(pendingTithe(entries), isEmpty);
    final summary = monthSummary(entries, await db.watchCategories().first, '2026-11');
    expect(summary.tithe, 40530);
    expect(summary.offering, 10132);
    expect(summary.available, 405301 + 5000 - 40530 - 10132);
    expect(summary.tithes.single.paid, isFalse); // nasce "a entregar"
    expect(summary.offerings.single.percentBp, 250);

    // Editar a entrada sem passar titheStatus mantém "separado".
    await db.saveEntry(
      id: salario,
      type: EntryType.receita,
      amount: 405301,
      date: '2026-11-05',
      description: 'Salário de novembro',
      accountId: 'seed-conta-carteira',
      paid: true,
    );
    expect((await db.getEntry(salario))!.titheStatus, TitheStatus.separado);
  });

  test('preferências: grava e lê', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.setSetting('offering_bp', '250');
    await db.setSetting('offering_bp', '300');
    expect((await db.watchSettings().first)['offering_bp'], '300');
    expect(await (db.select(db.settings)..where((s) => s.key.equals('offering_bp'))).get(), hasLength(1));
  });
}
