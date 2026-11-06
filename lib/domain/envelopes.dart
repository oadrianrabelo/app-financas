// Guardado: o saldo de cada envelope.
import '../data/database.dart';

/// Inicial + guardado (gastos com o envelope) − tirado (entradas com o envelope).
int envelopeBalance(Envelope env, Iterable<Entry> entries) {
  var b = env.initialBalance;
  for (final e in entries) {
    if (e.deletedAt != null || e.envelopeId != env.id) continue;
    if (e.type == EntryType.despesa) b += e.amount;
    if (e.type == EntryType.receita) b -= e.amount;
  }
  return b;
}
