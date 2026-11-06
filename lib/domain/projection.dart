// Próximos meses: quanto já está comprometido e quanto deve sobrar.
//
// Junta o que já está lançado no mês (parcelas, contas fixas já geradas,
// faturas de cartão) com as contas fixas que ainda vão aparecer, e estima o
// dízimo e a oferta das entradas previstas.
import '../core/dates.dart';
import '../data/database.dart';
import 'finance.dart';
import 'tithe.dart';

class MonthForecast {
  MonthForecast(this.month, this.summary, this.estimatedPrimicias);
  final String month;
  final MonthSummary summary;
  final int estimatedPrimicias; // dízimo + oferta estimados (ainda não separados)

  int get income => summary.income;
  int get committed => summary.expense + summary.tithe + summary.offering + estimatedPrimicias + summary.savedTotal;
  int get free => income - committed;
}

/// Lançamentos "virtuais" das contas fixas que ainda não existem em [month].
List<Entry> _virtualRecurring(Iterable<Recurring> recurrings, Iterable<Entry> entries, String month) {
  final existing = {for (final e in entries) e.id};
  return [
    for (final r in recurrings)
      if (r.deletedAt == null &&
          r.active &&
          r.startMonth.compareTo(month) <= 0 &&
          !existing.contains('rec-${r.id}-$month'))
        Entry(
          id: 'rec-${r.id}-$month',
          createdAt: 0,
          updatedAt: 0,
          type: r.type,
          amount: r.variable ? _lastAmount(r, entries) : r.amount,
          date: '$month-${r.day.toString().padLeft(2, '0')}',
          description: r.description,
          accountId: r.accountId,
          categoryId: r.categoryId,
          paid: false,
          recurringId: r.id,
          titheStatus: r.type == EntryType.receita ? TitheStatus.pendente : null,
        ),
  ];
}

int _lastAmount(Recurring r, Iterable<Entry> entries) {
  Entry? last;
  for (final e in entries) {
    if (e.recurringId == r.id && e.deletedAt == null && (last == null || e.date.compareTo(last.date) > 0)) last = e;
  }
  return last?.amount ?? r.amount;
}

List<MonthForecast> forecast({
  required String fromMonth,
  required int months,
  required List<Entry> entries,
  required List<Recurring> recurrings,
  required List<Category> categories,
  required Set<String> valeAccounts,
  required List<Account> cards,
  required int titheBp,
  required int offeringBp,
}) => [
  for (var i = 0; i < months; i++)
    () {
      final month = addMonths(fromMonth, i);
      final all = [...entries, ..._virtualRecurring(recurrings, entries, month)];
      final s = monthSummary(all, categories, month, valeAccounts: valeAccounts, cards: cards);
      final pendingIncome = s.incomes
          .where((e) => e.titheStatus == TitheStatus.pendente)
          .fold(0, (sum, e) => sum + e.amount);
      return MonthForecast(month, s, percentOf(pendingIncome, titheBp) + percentOf(pendingIncome, offeringBp));
    }(),
];
