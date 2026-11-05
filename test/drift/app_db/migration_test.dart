// dart format width=80
// ignore_for_file: unused_local_variable, unused_import
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:livro_caixa/data/database.dart';
import 'package:flutter_test/flutter_test.dart';

import 'generated/schema.dart';

import 'generated/schema_v1.dart' as v1;
import 'generated/schema_v2.dart' as v2;
import 'generated/schema_v3.dart' as v3;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  group('simple database migrations', () {
    // These simple tests verify all possible schema updates with a simple (no
    // data) migration. This is a quick way to ensure that written database
    // migrations properly alter the schema.
    const versions = GeneratedHelper.versions;
    for (final (i, fromVersion) in versions.indexed) {
      group('from $fromVersion', () {
        for (final toVersion in versions.skip(i + 1)) {
          test('to $toVersion', () async {
            final schema = await verifier.schemaAt(fromVersion);
            final db = AppDatabase(schema.newConnection());
            await verifier.migrateAndValidate(db, toVersion);
            await db.close();
          });
        }
      });
    }
  });

  // Dados do v1 sobrevivem e as categorias padrão ganham seção + Dízimo/Oferta.
  test('v1 -> v2 preserva os dados e cria Dízimo e Oferta', () async {
    await verifier.testWithDataIntegrity(
      oldVersion: 1,
      newVersion: 2,
      createOld: v1.DatabaseAtV1.new,
      createNew: v2.DatabaseAtV2.new,
      openTestedDatabase: AppDatabase.new,
      createItems: (batch, oldDb) {
        batch.insertAll(oldDb.categories, [
          const v1.CategoriesData(
            id: 'seed-cat-mercado',
            createdAt: 0,
            updatedAt: 0,
            name: 'Mercado',
            kind: 'despesa',
            icon: '🛒',
            color: 0xFF16A34A,
          ),
        ]);
        batch.insertAll(oldDb.entries, [
          const v1.EntriesData(
            id: 'e1',
            createdAt: 1,
            updatedAt: 1,
            type: 'receita',
            amount: 405301,
            date: '2026-11-05',
            description: 'Salário',
            accountId: 'seed-conta-carteira',
            paid: 1,
          ),
        ]);
      },
      validateItems: (newDb) async {
        final cats = {
          for (final c in await newDb.select(newDb.categories).get()) c.id: c,
        };
        expect(cats['seed-cat-mercado']!.section, 'casa');
        expect(cats['seed-cat-dizimo']!.section, 'primicias');
        expect(cats['seed-cat-oferta'], isNotNull);
        final entries = await newDb.select(newDb.entries).get();
        expect(entries.single.amount, 405301);
        expect(entries.single.titheStatus, isNull); // antigas não são cobradas
      },
    );
  });

  test('v2 -> v3 preserva lançamentos e cria as pessoas da casa', () async {
    await verifier.testWithDataIntegrity(
      oldVersion: 2,
      newVersion: 3,
      createOld: v2.DatabaseAtV2.new,
      createNew: v3.DatabaseAtV3.new,
      openTestedDatabase: AppDatabase.new,
      createItems: (batch, oldDb) {
        batch.insertAll(oldDb.entries, [
          const v2.EntriesData(
            id: 'e1',
            createdAt: 1,
            updatedAt: 1,
            type: 'receita',
            amount: 405301,
            date: '2026-11-05',
            description: 'Salário',
            accountId: 'seed-conta-carteira',
            paid: 1,
            titheStatus: 'separado',
          ),
        ]);
      },
      validateItems: (newDb) async {
        final e = (await newDb.select(newDb.entries).get()).single;
        expect(e.titheStatus, 'separado');
        expect(e.recurringId, isNull);
        expect((await newDb.select(newDb.people).get()).map((p) => p.name), [
          'Adrian',
          'Andressa',
        ]);
      },
    );
  });
}
