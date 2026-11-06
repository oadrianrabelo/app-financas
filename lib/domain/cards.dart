// Cartão de crédito: em que fatura cai cada compra.
//
// Uma compra feita até o dia do FECHAMENTO entra na fatura que fecha naquele
// mês; depois do fechamento, entra na do mês seguinte. A fatura aparece no
// mês do VENCIMENTO (é quando o dinheiro sai de verdade).
import '../core/dates.dart';
import '../data/database.dart';

bool isCard(Account a) => a.type == AccountType.cartao;

/// Mês ("AAAA-MM") em que vence a fatura de uma compra feita em [date].
String invoiceDueMonth(Account card, String date) {
  final c = card.closingDay;
  if (c == null) return monthOf(date); // sem fechamento: conta no próprio mês
  final day = int.parse(date.substring(8));
  final closing = day <= c ? monthOf(date) : addMonths(monthOf(date), 1);
  final d = card.dueDay ?? c;
  return d > c ? closing : addMonths(closing, 1);
}

class Invoice {
  Invoice(this.card, this.dueMonth);
  final Account card;
  final String dueMonth;
  final List<Entry> purchases = [];

  int get total => purchases.fold(0, (s, e) => s + e.amount);
  bool get paid => purchases.isNotEmpty && purchases.every((e) => e.paid);

  /// "AAAA-MM-DD" do vencimento.
  String get dueDate => '$dueMonth-${((card.dueDay ?? card.closingDay ?? 1).clamp(1, 28)).toString().padLeft(2, '0')}';
}

/// Faturas que vencem em [month], uma por cartão (só as que têm compras).
List<Invoice> invoicesFor(Iterable<Account> cards, Iterable<Entry> entries, String month) {
  final byCard = {for (final c in cards) c.id: Invoice(c, month)};
  for (final e in entries) {
    final inv = byCard[e.accountId];
    if (inv == null || e.deletedAt != null || e.type != EntryType.despesa) continue;
    if (invoiceDueMonth(inv.card, e.date) == month) inv.purchases.add(e);
  }
  return [
    for (final i in byCard.values)
      if (i.purchases.isNotEmpty) i..purchases.sort((a, b) => a.date.compareTo(b.date)),
  ];
}
