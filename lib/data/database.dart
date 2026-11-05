import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';
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
// Mudou alguma tabela? Rode `dart run build_runner build`, suba o
// `schemaVersion` e escreva a migração em `migration` (nunca apague dados).
// ---------------------------------------------------------------------------

enum AccountType { corrente, poupanca, carteira, cartao, investimento }

enum CategoryKind { despesa, receita }

enum EntryType { despesa, receita, transferencia }

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
}

/// Orçamento mensal por categoria (ainda sem tela: bom primeiro exercício!).
class Budgets extends Table with SyncColumns {
  TextColumn get categoryId => text()();
  TextColumn get month => text()(); // AAAA-MM
  IntColumn get limitAmount => integer()(); // centavos
}

const _uuid = Uuid();
String newId() => _uuid.v4();
int now() => DateTime.now().millisecondsSinceEpoch;

@DriftDatabase(tables: [Accounts, Categories, Entries, Budgets])
class AppDatabase extends _$AppDatabase {
  /// O arquivo `tostao.sqlite` fica na pasta de dados do app
  /// (Windows: %APPDATA%, Linux: `~/.local/share/<id>`, Android: dados do app).
  AppDatabase([QueryExecutor? executor])
    : super(
        executor ??
            driftDatabase(
              name: 'tostao',
              native: const DriftNativeOptions(databaseDirectory: getApplicationSupportDirectory),
            ),
      );

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _seed();
    },
    // onUpgrade: (m, from, to) async { if (from < 2) { ... } },
  );

  /// Dados iniciais com IDs FIXOS e updatedAt = 0: assim o celular e o PC
  /// criam as mesmas categorias, e a mesclagem não duplica nada (qualquer
  /// edição feita depois vence, porque tem updatedAt maior).
  Future<void> _seed() async {
    await into(accounts).insert(
      AccountsCompanion.insert(
        id: 'seed-conta-carteira',
        createdAt: 0,
        updatedAt: 0,
        name: 'Carteira',
        type: AccountType.carteira,
      ),
    );
    await batch((b) {
      b.insertAll(categories, [
        for (final (slug, name, kind, icon, color) in _defaultCategories)
          CategoriesCompanion.insert(
            id: 'seed-cat-$slug',
            createdAt: 0,
            updatedAt: 0,
            name: name,
            kind: kind,
            icon: icon,
            color: color,
          ),
      ]);
    });
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
      ),
    );
  }

  /// Cria (id == null) ou atualiza um lançamento.
  Future<void> saveEntry({
    String? id,
    required EntryType type,
    required int amount,
    required String date,
    required String description,
    required String accountId,
    String? toAccountId,
    String? categoryId,
    required bool paid,
  }) {
    final t = now();
    final data = EntriesCompanion(
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
    if (id != null) return (update(entries)..where((e) => e.id.equals(id))).write(data);
    return into(entries).insert(data.copyWith(id: Value(newId()), createdAt: Value(t)));
  }

  Future<void> markPaid(String id) => (update(
    entries,
  )..where((e) => e.id.equals(id))).write(EntriesCompanion(paid: const Value(true), updatedAt: Value(now())));

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

const _defaultCategories = <(String, String, CategoryKind, String, int)>[
  ('mercado', 'Mercado', CategoryKind.despesa, '🛒', 0xFF16A34A),
  ('moradia', 'Moradia', CategoryKind.despesa, '🏠', 0xFF2563EB),
  ('contas', 'Contas da casa', CategoryKind.despesa, '💡', 0xFFCA8A04),
  ('transporte', 'Transporte', CategoryKind.despesa, '🚗', 0xFF9333EA),
  ('saude', 'Saúde', CategoryKind.despesa, '🩺', 0xFFDC2626),
  ('lazer', 'Lazer', CategoryKind.despesa, '🎉', 0xFFDB2777),
  ('restaurantes', 'Restaurantes', CategoryKind.despesa, '🍔', 0xFFEA580C),
  ('educacao', 'Educação', CategoryKind.despesa, '📚', 0xFF0891B2),
  ('assinaturas', 'Assinaturas', CategoryKind.despesa, '📺', 0xFF4F46E5),
  ('outros', 'Outros', CategoryKind.despesa, '📦', 0xFF64748B),
  ('salario', 'Salário', CategoryKind.receita, '💼', 0xFF059669),
  ('extra', 'Extra', CategoryKind.receita, '✨', 0xFF0D9488),
  ('rendimentos', 'Rendimentos', CategoryKind.receita, '📈', 0xFF65A30D),
];
