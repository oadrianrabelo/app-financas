import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'database.steps.dart';

import 'package:uuid/uuid.dart';

part 'database.g.dart';

// ---------------------------------------------------------------------------
// Modelo de dados (SQLite, via drift)
//
// Regras que deixam o app pronto para juntar dados de dois aparelhos:
//  - IDs são UUIDs gerados no aparelho -> sem colisão entre o seu celular e
//    o da sua esposa.
//  - Todo registro tem `updatedAt` -> na mesclagem, a versão mais nova vence.
//  - Nada é apagado de verdade: marcamos `deletedAt` ("lápide"), assim a
//    exclusão também viaja na mesclagem.
//
// Mudou alguma tabela? Passo a passo (nunca apague dados):
//  1. Edite as tabelas e suba o `schemaVersion`.
//  2. `dart run build_runner build` e depois `dart run drift_dev make-migrations`
//     (guarda o esquema novo em drift_schemas/ e gera database.steps.dart).
//  3. Escreva o passo `fromXToY` em `migration` e rode os testes:
//     test/drift/ confere que a migração chega exatamente no esquema novo.
// ---------------------------------------------------------------------------

enum AccountType { corrente, poupanca, carteira, cartao, investimento }

enum CategoryKind { despesa, receita }

enum EntryType { despesa, receita, transferencia }

/// Situação do dízimo e da oferta de uma ENTRADA (receita).
/// - pendente: ainda não separado (o app lembra na página do mês)
/// - separado: dízimo e oferta já lançados
/// - isento: não gera dízimo (ex.: um empréstimo que voltou)
/// Nulo em despesas e transferências.
enum TitheStatus { pendente, separado, isento }

/// Seções da página do mês, como no caderno.
enum CategorySection { primicias, cartao, casa, pessoal, outros }

/// IDs fixos das categorias especiais (criadas pelo app, ver _seedCategories).
const dizimoCategoryId = 'seed-cat-dizimo';
const ofertaCategoryId = 'seed-cat-oferta';

mixin SyncColumns on Table {
  TextColumn get id => text()();
  IntColumn get createdAt => integer()(); // millisecondsSinceEpoch
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Accounts extends Table with SyncColumns {
  TextColumn get name => text()();
  TextColumn get type => textEnum<AccountType>()();
  IntColumn get initialBalance => integer().withDefault(const Constant(0))(); // centavos
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
}

class Categories extends Table with SyncColumns {
  TextColumn get name => text()();
  TextColumn get kind => textEnum<CategoryKind>()();
  TextColumn get icon => text()(); // emoji
  IntColumn get color => integer()(); // 0xAARRGGBB
  TextColumn get section => textEnum<CategorySection>().nullable()(); // só despesas
}

/// Lançamentos (despesa, receita ou transferência).
class Entries extends Table with SyncColumns {
  TextColumn get type => textEnum<EntryType>()();
  IntColumn get amount => integer()(); // centavos, sempre positivo
  TextColumn get date => text()(); // AAAA-MM-DD
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get accountId => text()();
  TextColumn get toAccountId => text().nullable()(); // só transferências
  TextColumn get categoryId => text().nullable()();
  BoolColumn get paid => boolean().withDefault(const Constant(true))();
  TextColumn get notes => text().nullable()();
  TextColumn get titheStatus => textEnum<TitheStatus>().nullable()();
  IntColumn get percentBp => integer().nullable()(); // dízimo/oferta: % usado, em centésimos (250 = 2,5%)
}

/// Orçamento mensal por categoria (ainda sem tela: bom primeiro exercício!).
class Budgets extends Table with SyncColumns {
  TextColumn get categoryId => text()();
  TextColumn get month => text()(); // AAAA-MM
  IntColumn get limitAmount => integer()(); // centavos
}

/// Preferências deste aparelho (percentuais, fontes, tema). Chave -> valor em texto.
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

const _uuid = Uuid();
String newId() => _uuid.v4();
int now() => DateTime.now().millisecondsSinceEpoch;

@DriftDatabase(tables: [Accounts, Categories, Entries, Budgets, Settings])
class AppDatabase extends _$AppDatabase {
  /// O arquivo `livro_caixa.sqlite` fica na pasta de dados do app
  /// (Windows: %APPDATA%, Linux: `~/.local/share/<id>`, Android: dados do app).
  AppDatabase([QueryExecutor? executor])
    : super(
        executor ??
            driftDatabase(
              name: 'livro_caixa',
              native: const DriftNativeOptions(databaseDirectory: getApplicationSupportDirectory),
            ),
      );

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await into(accounts).insert(
        AccountsCompanion.insert(
          id: 'seed-conta-carteira',
          createdAt: 0,
          updatedAt: 0,
          name: 'Carteira',
          type: AccountType.carteira,
        ),
      );
      await _seedCategories();
    },
    onUpgrade: stepByStep(
      from1To2: (m, schema) async {
        await m.addColumn(schema.categories, schema.categories.section);
        await m.addColumn(schema.entries, schema.entries.titheStatus);
        await m.addColumn(schema.entries, schema.entries.percentBp);
        await m.createTable(schema.settings);
        await _seedCategories(); // cria Dízimo, Oferta etc. e preenche as seções
      },
    ),
  );

  /// Categorias padrão com IDs FIXOS e updatedAt = 0: assim o celular e o PC
  /// criam as mesmas, e a mesclagem do backup não duplica nada (qualquer
  /// edição feita depois vence, porque tem updatedAt maior).
  /// Roda na criação e nas migrações: só insere o que falta e só preenche a
  /// seção de quem ainda não tem.
  Future<void> _seedCategories() async {
    for (final (slug, name, kind, icon, color, section) in _defaultCategories) {
      await customStatement(
        'INSERT OR IGNORE INTO categories (id, created_at, updated_at, name, kind, icon, color, section) '
        'VALUES (?, 0, 0, ?, ?, ?, ?, ?)',
        ['seed-cat-$slug', name, kind.name, icon, color, section?.name],
      );
      if (section != null) {
        await customStatement('UPDATE categories SET section = ? WHERE id = ? AND section IS NULL', [
          section.name,
          'seed-cat-$slug',
        ]);
      }
    }
  }

  // ---- Leituras (Streams: a tela se atualiza sozinha quando o banco muda) ----

  Stream<List<Account>> watchAccounts() =>
      (select(accounts)
            ..where((a) => a.deletedAt.isNull())
            ..orderBy([(a) => OrderingTerm(expression: a.name)]))
          .watch();

  Stream<List<Category>> watchCategories() =>
      (select(categories)
            ..where((c) => c.deletedAt.isNull())
            ..orderBy([(c) => OrderingTerm(expression: c.name)]))
          .watch();

  Stream<List<Entry>> watchAllEntries() => (select(entries)..where((e) => e.deletedAt.isNull())).watch();

  /// Lançamentos de um mês ("AAAA-MM"), mais recentes primeiro.
  Stream<List<Entry>> watchMonthEntries(String month) =>
      (select(entries)
            ..where((e) => e.deletedAt.isNull() & e.date.like('$month-%'))
            ..orderBy([(e) => OrderingTerm.desc(e.date), (e) => OrderingTerm.desc(e.createdAt)]))
          .watch();

  // ---- Escritas ----

  Future<void> addAccount({required String name, required AccountType type, int initialBalance = 0}) {
    final t = now();
    return into(accounts).insert(
      AccountsCompanion.insert(
        id: newId(),
        createdAt: t,
        updatedAt: t,
        name: name,
        type: type,
        initialBalance: Value(initialBalance),
      ),
    );
  }

  Future<void> setAccountArchived(String id, bool archived) => (update(
    accounts,
  )..where((a) => a.id.equals(id))).write(AccountsCompanion(archived: Value(archived), updatedAt: Value(now())));

  Future<void> addCategory({
    required String name,
    required CategoryKind kind,
    required String icon,
    required int color,
    CategorySection? section,
  }) {
    final t = now();
    return into(categories).insert(
      CategoriesCompanion.insert(
        id: newId(),
        createdAt: t,
        updatedAt: t,
        name: name,
        kind: kind,
        icon: icon,
        color: color,
        section: Value(section),
      ),
    );
  }

  Future<Entry?> getEntry(String id) => (select(entries)..where((e) => e.id.equals(id))).getSingleOrNull();

  /// Cria (id == null) ou atualiza um lançamento. Devolve o id.
  /// [titheStatus]: só para receitas; `null` mantém o que já estava.
  Future<String> saveEntry({
    String? id,
    required EntryType type,
    required int amount,
    required String date,
    required String description,
    required String accountId,
    String? toAccountId,
    String? categoryId,
    required bool paid,
    TitheStatus? titheStatus,
  }) async {
    final t = now();
    var data = EntriesCompanion(
      type: Value(type),
      amount: Value(amount),
      date: Value(date),
      description: Value(description),
      accountId: Value(accountId),
      toAccountId: Value(toAccountId),
      categoryId: Value(categoryId),
      paid: Value(paid),
      updatedAt: Value(t),
    );
    if (type != EntryType.receita) {
      data = data.copyWith(titheStatus: const Value(null));
    } else if (titheStatus != null) {
      data = data.copyWith(titheStatus: Value(titheStatus));
    }
    if (id != null) {
      await (update(entries)..where((e) => e.id.equals(id))).write(data);
      return id;
    }
    final newEntryId = newId();
    await into(entries).insert(data.copyWith(id: Value(newEntryId), createdAt: Value(t)));
    return newEntryId;
  }

  Future<void> setPaid(String id, bool paid) => (update(
    entries,
  )..where((e) => e.id.equals(id))).write(EntriesCompanion(paid: Value(paid), updatedAt: Value(now())));

  Future<void> markPaid(String id) => setPaid(id, true);

  Future<void> setTitheStatus(Iterable<String> ids, TitheStatus status) => (update(
    entries,
  )..where((e) => e.id.isIn(ids))).write(EntriesCompanion(titheStatus: Value(status), updatedAt: Value(now())));

  /// Lança o dízimo e a oferta e marca as [incomes] como "separado".
  /// Valores zerados não viram lançamento. Os lançamentos nascem como
  /// "a entregar" (não pagos): marque ✓ quando entregar na igreja.
  Future<void> separateTithe({
    required List<Entry> incomes,
    required int tithe,
    required int titheBp,
    required int offering,
    required int offeringBp,
  }) {
    final date = incomes.map((e) => e.date).reduce((a, b) => a.compareTo(b) >= 0 ? a : b);
    final accountId = incomes.first.accountId;
    return transaction(() async {
      final t = now();
      for (final (amount, bp, categoryId, label) in [
        (tithe, titheBp, dizimoCategoryId, 'Dízimo'),
        (offering, offeringBp, ofertaCategoryId, 'Oferta'),
      ]) {
        if (amount <= 0) continue;
        await into(entries).insert(
          EntriesCompanion.insert(
            id: newId(),
            createdAt: t,
            updatedAt: t,
            type: EntryType.despesa,
            amount: amount,
            date: date,
            description: Value(label),
            accountId: accountId,
            categoryId: Value(categoryId),
            paid: const Value(false),
            percentBp: Value(bp),
          ),
        );
      }
      await setTitheStatus(incomes.map((e) => e.id), TitheStatus.separado);
    });
  }

  // ---- Preferências ----

  Stream<Map<String, String>> watchSettings() =>
      select(settings).watch().map((rows) => {for (final r in rows) r.key: r.value});

  Future<void> setSetting(String key, String value) =>
      into(settings).insertOnConflictUpdate(Setting(key: key, value: value));

  /// Exclusão lógica: marca `deletedAt` (funciona em qualquer tabela com SyncColumns).
  Future<void> softDelete(TableInfo<Table, dynamic> table, String id) {
    final t = now();
    return customUpdate(
      'UPDATE ${table.actualTableName} SET deleted_at = ?, updated_at = ? WHERE id = ?',
      variables: [Variable.withInt(t), Variable.withInt(t), Variable.withString(id)],
      updates: {table},
    );
  }
}

const _defaultCategories = <(String, String, CategoryKind, String, int, CategorySection?)>[
  // Primícias: separadas pelo botão "Separar dízimo e oferta"
  ('dizimo', 'Dízimo', CategoryKind.despesa, '⛪', 0xFF7C5C2E, CategorySection.primicias),
  ('oferta', 'Oferta', CategoryKind.despesa, '🕊️', 0xFF9A7B4F, CategorySection.primicias),
  // Cartão
  ('fatura', 'Fatura do cartão', CategoryKind.despesa, '💳', 0xFF4F46E5, CategorySection.cartao),
  // Casa
  ('mercado', 'Mercado', CategoryKind.despesa, '🛒', 0xFF16A34A, CategorySection.casa),
  ('moradia', 'Moradia', CategoryKind.despesa, '🏠', 0xFF2563EB, CategorySection.casa),
  ('contas', 'Contas da casa', CategoryKind.despesa, '💡', 0xFFCA8A04, CategorySection.casa),
  // Pessoal
  ('transporte', 'Transporte', CategoryKind.despesa, '🚗', 0xFF9333EA, CategorySection.pessoal),
  ('saude', 'Saúde', CategoryKind.despesa, '🩺', 0xFFDC2626, CategorySection.pessoal),
  ('lazer', 'Lazer', CategoryKind.despesa, '🎉', 0xFFDB2777, CategorySection.pessoal),
  ('restaurantes', 'Restaurantes', CategoryKind.despesa, '🍔', 0xFFEA580C, CategorySection.pessoal),
  ('educacao', 'Educação', CategoryKind.despesa, '📚', 0xFF0891B2, CategorySection.pessoal),
  ('assinaturas', 'Assinaturas', CategoryKind.despesa, '📺', 0xFF4F46E5, CategorySection.pessoal),
  ('outros', 'Outros', CategoryKind.despesa, '📦', 0xFF64748B, CategorySection.outros),
  // Entradas (todas geram dízimo e oferta, a não ser que a entrada seja marcada como isenta)
  ('salario', 'Salário', CategoryKind.receita, '💼', 0xFF059669, null),
  ('extra', 'Extra', CategoryKind.receita, '✨', 0xFF0D9488, null),
  ('alfajor', 'Alfajor', CategoryKind.receita, '🍪', 0xFFB45309, null),
  ('corridas', 'Corridas e entregas', CategoryKind.receita, '🛵', 0xFF0369A1, null),
  ('rendimentos', 'Rendimentos', CategoryKind.receita, '📈', 0xFF65A30D, null),
];
