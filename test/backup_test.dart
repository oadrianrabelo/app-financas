import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tostao/backup/backup.dart';
import 'package:tostao/data/database.dart';

void main() {
  test('mescla mantendo a versão mais recente de cada registro', () async {
    final celular = AppDatabase(NativeDatabase.memory());
    final pc = AppDatabase(NativeDatabase.memory());
    addTearDown(() async {
      await celular.close();
      await pc.close();
    });

    await celular.saveEntry(
      type: EntryType.despesa,
      amount: 1000,
      date: '2026-11-05',
      description: 'Pão',
      accountId: 'seed-conta-carteira',
      paid: true,
    );

    // primeira "sincronização": o lançamento vai para o PC, categorias não duplicam
    final first = await importData(pc, await exportData(celular));
    expect(first.added, 1);
    expect((await pc.watchCategories().first).length, 13);

    final acc = (await celular.select(celular.accounts).get()).first;
    await (pc.update(pc.accounts)..where((a) => a.id.equals(acc.id))).write(
      AccountsCompanion(name: const Value('PC (velho)'), updatedAt: Value(acc.updatedAt + 1)),
    );
    await (celular.update(celular.accounts)..where((a) => a.id.equals(acc.id))).write(
      AccountsCompanion(name: const Value('Celular (novo)'), updatedAt: Value(acc.updatedAt + 2)),
    );
    await celular.softDelete(celular.categories, (await celular.select(celular.categories).get()).first.id);

    final second = await importData(pc, await exportData(celular));
    expect(second.updated, 2);
    final pcAcc = await (pc.select(pc.accounts)..where((a) => a.id.equals(acc.id))).getSingle();
    expect(pcAcc.name, 'Celular (novo)');
    expect((await pc.watchCategories().first).length, 12); // a exclusão viajou
  });

  test('recusa arquivos que não são backup', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    expect(() => importData(db, {'foo': 1}), throwsFormatException);
  });
}
