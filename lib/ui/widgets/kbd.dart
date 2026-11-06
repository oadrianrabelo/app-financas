import 'dart:io';

import 'package:flutter/material.dart';

import '../theme/paper.dart';

/// Tecla de atalho desenhada como no Mac/Raycast: [⌘] [K].
class Kbd extends StatelessWidget {
  const Kbd(this.keys, {super.key, this.inverted = false});
  final List<String> keys;
  final bool inverted; // sobre fundo escuro (botão principal)

  /// "⌘" no Mac, "Ctrl" nos outros.
  static String get mod => Platform.isMacOS ? '⌘' : 'Ctrl';

  @override
  Widget build(BuildContext context) {
    final p = Paper.of(context);
    final fg = inverted ? p.paper.withValues(alpha: 0.75) : p.pencil;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final k in keys)
          Container(
            margin: const EdgeInsets.only(left: 3),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: fg.withValues(alpha: 0.35)),
            ),
            child: Text(
              k,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
            ),
          ),
      ],
    );
  }
}

/// Atalhos de teclado só fazem sentido no computador.
bool get isDesktop => Platform.isWindows || Platform.isLinux || Platform.isMacOS;
