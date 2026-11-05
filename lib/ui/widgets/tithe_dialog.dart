import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../../data/app_data.dart';
import '../../data/database.dart';
import '../../domain/tithe.dart';
import '../theme/paper.dart';

/// "Separar dízimo e oferta agora?"
/// [incomes]: as entradas que ficam marcadas como "separado".
/// [base]: sobre quanto calcular (padrão: a soma das entradas). Use para
/// separar só a diferença quando uma entrada aumentou.
/// Devolve true se separou.
Future<bool> showTitheDialog(BuildContext context, {required List<Entry> incomes, int? base}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => _TitheDialog(incomes: incomes, base: base ?? incomes.fold(0, (s, e) => s + e.amount)),
  );
  if (ok == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dízimo e oferta separados. ✓')));
  }
  return ok ?? false;
}

class _TitheDialog extends StatefulWidget {
  const _TitheDialog({required this.incomes, required this.base});
  final List<Entry> incomes;
  final int base;

  @override
  State<_TitheDialog> createState() => _TitheDialogState();
}

class _TitheDialogState extends State<_TitheDialog> {
  bool _adjusting = false;
  bool _ready = false;
  bool _offeringPctTyped = false; // só o % digitado vira o novo padrão
  late int _titheBp, _offeringBp, _tithe, _offering;
  final _tithePct = TextEditingController();
  final _titheValue = TextEditingController();
  final _offeringPct = TextEditingController();
  final _offeringValue = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    _ready = true;
    final scope = AppScope.of(context);
    final prefs = scope.prefs;
    // Oferta: o percentual definido; se nunca definiram, o da última oferta lançada.
    final lastOffering = scope.data.entries
        .where((e) => e.categoryId == ofertaCategoryId && e.percentBp != null)
        .fold<Entry?>(null, (last, e) => last == null || e.date.compareTo(last.date) >= 0 ? e : last);
    final offeringBp = prefs.hasOfferingBp ? prefs.offeringBp : lastOffering?.percentBp ?? prefs.offeringBp;
    final s = TitheSuggestion(base: widget.base, titheBp: prefs.titheBp, offeringBp: offeringBp);
    _titheBp = s.titheBp;
    _offeringBp = s.offeringBp;
    _tithe = s.tithe;
    _offering = s.offering;
    _syncFields();
  }

  void _syncFields() {
    _tithePct.text = formatBp(_titheBp).replaceAll('%', '');
    _titheValue.text = centsToInput(_tithe);
    _offeringPct.text = formatBp(_offeringBp).replaceAll('%', '');
    _offeringValue.text = centsToInput(_offering);
  }

  // Mexeu no percentual -> recalcula o valor, e vice-versa.
  void _onPct(bool tithe, String v) {
    final bp = parseBp(v);
    if (bp == null) return;
    setState(() {
      if (tithe) {
        _titheBp = bp;
        _tithe = percentOf(widget.base, bp);
        _titheValue.text = centsToInput(_tithe);
      } else {
        _offeringPctTyped = true;
        _offeringBp = bp;
        _offering = percentOf(widget.base, bp);
        _offeringValue.text = centsToInput(_offering);
      }
    });
  }

  void _onValue(bool tithe, String v) {
    final cents = parseBRL(v);
    if (cents == null || cents < 0) return;
    setState(() {
      if (tithe) {
        _tithe = cents;
        _titheBp = bpOf(cents, widget.base);
        _tithePct.text = formatBp(_titheBp).replaceAll('%', '');
      } else {
        _offering = cents;
        _offeringBp = bpOf(cents, widget.base);
        _offeringPct.text = formatBp(_offeringBp).replaceAll('%', '');
      }
    });
  }

  Future<void> _separate() async {
    final scope = AppScope.of(context);
    await scope.db.separateTithe(
      incomes: widget.incomes,
      tithe: _tithe,
      titheBp: _titheBp,
      offering: _offering,
      offeringBp: _offeringBp,
    );
    // O app lembra o último percentual da oferta (para vocês irem aumentando).
    // Sem padrão ainda: grava o sugerido. Depois, só muda se o % foi digitado.
    if (!scope.prefs.hasOfferingBp && _offering > 0 && !_adjusting) {
      await scope.prefs.setOfferingBp(_offeringBp);
    } else if (_offeringPctTyped && _offeringBp != scope.prefs.offeringBp) {
      await scope.prefs.setOfferingBp(_offeringBp);
    }
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final p = Paper.of(context);
    Widget line(String label, int value, {bool bold = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: p.hand(22, weight: bold ? FontWeight.w700 : null)),
          ),
          Text(formatBRL(value), style: p.mono(15, weight: bold ? FontWeight.w700 : null)),
        ],
      ),
    );
    Widget fields(String label, TextEditingController pct, TextEditingController value, bool tithe) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 70, child: Text(label, style: p.hand(21))),
          SizedBox(
            width: 80,
            child: TextField(
              controller: pct,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(suffixText: '%', isDense: true),
              onChanged: (v) => _onPct(tithe, v),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: value,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(prefixText: r'R$ ', isDense: true),
              onChanged: (v) => _onValue(tithe, v),
            ),
          ),
        ],
      ),
    );

    return AlertDialog(
      title: Text(
        'Separar dízimo e oferta agora?',
        style: p.hand(28, color: p.redInk, weight: FontWeight.w700),
      ),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            line(
              widget.incomes.length == 1 ? 'Sobre esta entrada' : 'Sobre ${widget.incomes.length} entradas',
              widget.base,
            ),
            const Divider(),
            if (_adjusting) ...[
              fields('Dízimo', _tithePct, _titheValue, true),
              fields('Oferta', _offeringPct, _offeringValue, false),
            ] else ...[
              line('Dízimo (${formatBp(_titheBp)})', _tithe),
              line('Oferta (${formatBp(_offeringBp)})', _offering),
            ],
            const Divider(),
            line('Fica disponível', widget.base - _tithe - _offering, bold: true),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Agora não')),
        if (!_adjusting) TextButton(onPressed: () => setState(() => _adjusting = true), child: const Text('Ajustar…')),
        FilledButton(onPressed: _separate, child: const Text('Separar')),
      ],
    );
  }
}
