import 'package:flutter/material.dart';

import '../../data/app_data.dart';
import '../../updates/updater.dart';
import '../kit/kit.dart';
import '../theme/paper.dart';

/// Aparece no topo quando uma versão nova já foi baixada.
class UpdateBanner extends StatelessWidget {
  const UpdateBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final updater = AppScope.of(context).updater;
    return ListenableBuilder(
      listenable: updater,
      builder: (context, _) {
        final s = updater.status;
        if (s != UpdateStatus.ready && s != UpdateStatus.permissionRequired && s != UpdateStatus.installing) {
          return const SizedBox.shrink();
        }
        final version = updater.available?.version ?? '';
        final message = switch (s) {
          UpdateStatus.permissionRequired =>
            'Permita que o Livro-Caixa instale atualizações na tela que abriu, volte aqui e toque de novo.',
          UpdateStatus.installing => 'Instalando a versão $version…',
          _ => 'A versão $version está pronta.',
        };
        final p = Paper.of(context);
        return Container(
          margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
          decoration: BoxDecoration(
            color: p.paper,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: hairline(p)),
            boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 2))],
          ),
          child: Row(
            children: [
              Icon(LucideIcons.sparkles, size: 17, color: p.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(message, style: TextStyle(fontSize: 13.5, color: p.ink)),
              ),
              const SizedBox(width: 8),
              LcButton(
                s == UpdateStatus.permissionRequired ? 'Tentar de novo' : 'Atualizar agora',
                small: true,
                onPressed: s == UpdateStatus.installing ? null : updater.install,
              ),
            ],
          ),
        );
      },
    );
  }
}
