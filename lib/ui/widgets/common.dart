import 'package:flutter/material.dart';

import '../../core/dates.dart';

/// Página com largura máxima confortável no computador.
class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.title, this.trailing, required this.children, this.fab});
  final String title;
  final Widget? trailing;
  final List<Widget> children;
  final Widget? fab;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: fab,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                children: [
                  Text(title, style: Theme.of(context).textTheme.headlineSmall),
                  ?trailing,
                ],
              ),
              const SizedBox(height: 12),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class MonthPicker extends StatelessWidget {
  const MonthPicker({super.key, required this.month, required this.onChanged});
  final String month;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Mês anterior',
          icon: const Icon(Icons.chevron_left),
          onPressed: () => onChanged(addMonths(month, -1)),
        ),
        SizedBox(
          width: 190,
          child: Text(
            monthLabel(month),
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        IconButton(
          tooltip: 'Próximo mês',
          icon: const Icon(Icons.chevron_right),
          onPressed: () => onChanged(addMonths(month, 1)),
        ),
      ],
    );
  }
}

/// Cores de dinheiro positivo/negativo que funcionam no tema claro e escuro.
Color moneyColor(BuildContext context, {required bool positive}) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  if (positive) return dark ? const Color(0xFF34D399) : const Color(0xFF059669);
  return dark ? const Color(0xFFF87171) : const Color(0xFFDC2626);
}

Future<bool> confirm(BuildContext context, String message) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Confirmar')),
      ],
    ),
  );
  return ok ?? false;
}
