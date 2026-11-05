// Regras de negócio puras (sem banco, sem tela) -> fáceis de testar.
import '../data/database.dart';

/// Saldo atual de uma conta, considerando só lançamentos pagos.
int accountBalance(Account account, Iterable<Entry> entries) {
  var balance = account.initialBalance;
  for (final e in entries) {
    if (e.deletedAt != null || !e.paid) continue;
    switch (e.type) {
      case EntryType.receita when e.accountId == account.id:
        balance += e.amount;
      case EntryType.despesa when e.accountId == account.id:
        balance -= e.amount;
      case EntryType.transferencia:
        if (e.accountId == account.id) balance -= e.amount;
        if (e.toAccountId == account.id) balance += e.amount;
      default:
    }
  }
  return balance;
}

/// A página do mês, como no caderno:
///   Entradas − Dízimo − Oferta = Disponível
///   Disponível − (Cartão + Casa + Pessoal + Outros) = Sobrou
class MonthSummary {
  final List<Entry> incomes = [];
  final List<Entry> tithes = [];
  final List<Entry> offerings = [];

  /// Gastos por seção, na ordem do caderno (sem as primícias).
  final Map<CategorySection, List<Entry>> sections = {
    CategorySection.cartao: [],
    CategorySection.casa: [],
    CategorySection.pessoal: [],
    CategorySection.outros: [],
  };

  /// Gastos pagos com o vale-alimentação: aparecem, mas não saem do Disponível.
  final List<Entry> vale = [];

  int get income => _sum(incomes);
  int get valeSpent => _sum(vale);
  int get tithe => _sum(tithes);
  int get offering => _sum(offerings);

  /// O que temos depois de tirar o que é de Deus. É daqui que se conta.
  int get available => income - tithe - offering;
  int sectionTotal(CategorySection s) => _sum(sections[s]!);
  int get expense => sections.values.fold(0, (sum, list) => sum + _sum(list));
  int get left => available - expense;

  /// Gastos (e primícias) ainda não pagos/entregues.
  int get unpaid => [
    ...tithes,
    ...offerings,
    for (final l in sections.values) ...l,
  ].where((e) => !e.paid).fold(0, (s, e) => s + e.amount);

  static int _sum(List<Entry> l) => l.fold(0, (s, e) => s + e.amount);
}

/// Resumo de um mês ("AAAA-MM"). Transferências não entram (o dinheiro só muda de lugar).
/// Lançamentos nas contas [valeAccounts] (vale-alimentação) ficam à parte.
MonthSummary monthSummary(
  Iterable<Entry> entries,
  Iterable<Category> categories,
  String month, {
  Set<String> valeAccounts = const {},
}) {
  final sectionOf = {for (final c in categories) c.id: c.section};
  final s = MonthSummary();
  for (final e in entries) {
    if (e.deletedAt != null || !e.date.startsWith(month)) continue;
    if (valeAccounts.contains(e.accountId)) {
      if (e.type == EntryType.despesa) s.vale.add(e);
      continue;
    }
    switch (e.type) {
      case EntryType.receita:
        s.incomes.add(e);
      case EntryType.despesa when e.categoryId == dizimoCategoryId:
        s.tithes.add(e);
      case EntryType.despesa when e.categoryId == ofertaCategoryId:
        s.offerings.add(e);
      case EntryType.despesa:
        final section = sectionOf[e.categoryId] ?? CategorySection.outros;
        s.sections[section == CategorySection.primicias ? CategorySection.outros : section]!.add(e);
      case EntryType.transferencia:
    }
  }
  for (final l in [s.incomes, s.tithes, s.offerings, s.vale, ...s.sections.values]) {
    l.sort((a, b) => a.date.compareTo(b.date) != 0 ? a.date.compareTo(b.date) : a.createdAt.compareTo(b.createdAt));
  }
  return s;
}
