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

class MonthSummary {
  int income = 0;
  int expense = 0;
  int pending = 0; // despesas ainda não pagas no mês
  final Map<String?, int> byCategory = {}; // despesas por categoria (null = sem categoria)

  int get balance => income - expense;
}

/// Resumo de um mês ("AAAA-MM"). Transferências não contam como receita/despesa.
MonthSummary monthSummary(Iterable<Entry> entries, String month) {
  final s = MonthSummary();
  for (final e in entries) {
    if (e.deletedAt != null || !e.date.startsWith(month)) continue;
    if (e.type == EntryType.receita) s.income += e.amount;
    if (e.type == EntryType.despesa) {
      s.expense += e.amount;
      if (!e.paid) s.pending += e.amount;
      s.byCategory.update(e.categoryId, (v) => v + e.amount, ifAbsent: () => e.amount);
    }
  }
  return s;
}
