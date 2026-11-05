// Dízimo e oferta: regras puras (sem banco, sem tela).
//
// Percentuais em "pontos-base" (centésimos de %): 1000 = 10%, 250 = 2,5%.
// Assim não usamos double nem para o percentual.
import '../data/database.dart';

const defaultTitheBp = 1000; // 10%
const defaultOfferingBp = 100; // 1%

/// Parte de um valor. Arredonda para BAIXO no centavo, como no caderno:
/// 10% de 4.053,01 = 405,30 · 2,5% = 101,32 · 1% = 40,53.
int percentOf(int cents, int bp) => cents * bp ~/ 10000;

/// Inverso: que percentual (em bp) um valor representa da base.
int bpOf(int part, int base) => base == 0 ? 0 : (part * 10000 / base).round();

/// "2,5%" a partir de 250
String formatBp(int bp) {
  final s = (bp / 100).toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
  return '${s.replaceFirst('.', ',')}%';
}

/// Converte "2,5" ou "2.5" ou "10" em bp. Null se inválido.
int? parseBp(String input) {
  final s = input.replaceAll('%', '').replaceAll(',', '.').trim();
  final v = double.tryParse(s);
  if (v == null || v < 0 || v > 100) return null;
  return (v * 100).round();
}

/// Entradas que ainda esperam o dízimo ser separado.
List<Entry> pendingTithe(Iterable<Entry> entries, {String? month}) => [
  for (final e in entries)
    if (e.deletedAt == null &&
        e.type == EntryType.receita &&
        e.titheStatus == TitheStatus.pendente &&
        (month == null || e.date.startsWith(month)))
      e,
];

class TitheSuggestion {
  const TitheSuggestion({required this.base, required this.titheBp, required this.offeringBp});
  final int base;
  final int titheBp;
  final int offeringBp;

  int get tithe => percentOf(base, titheBp);
  int get offering => percentOf(base, offeringBp);
}
