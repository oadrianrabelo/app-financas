// Vale-alimentação: dinheiro separado, que NÃO entra no Disponível.
// Renova todo mês no dia `renewDay` com `renewAmount`. O app só mostra quanto
// resta até a próxima renovação (se vocês lançarem as compras com o vale).
import '../data/database.dart';

class ValeStatus {
  const ValeStatus({required this.periodStart, required this.nextRenewal, required this.amount, required this.spent});
  final DateTime periodStart; // última renovação
  final DateTime nextRenewal;
  final int amount; // valor da renovação
  final int spent; // gasto desde a última renovação

  int get left => amount - spent;
  int daysUntilRenewal(DateTime today) => DateTime(
    nextRenewal.year,
    nextRenewal.month,
    nextRenewal.day,
  ).difference(DateTime(today.year, today.month, today.day)).inDays;
}

String _iso(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

ValeStatus valeStatus(Account vale, Iterable<Entry> entries, DateTime today) {
  final day = (vale.renewDay ?? 1).clamp(1, 28);
  final thisMonth = DateTime(today.year, today.month, day);
  final start = today.day >= day ? thisMonth : DateTime(today.year, today.month - 1, day);
  final next = DateTime(start.year, start.month + 1, day);
  final from = _iso(start), until = _iso(next);
  var spent = 0;
  for (final e in entries) {
    if (e.deletedAt != null || e.accountId != vale.id || e.type != EntryType.despesa) continue;
    if (e.date.compareTo(from) >= 0 && e.date.compareTo(until) < 0) spent += e.amount;
  }
  return ValeStatus(periodStart: start, nextRenewal: next, amount: vale.renewAmount ?? 0, spent: spent);
}
