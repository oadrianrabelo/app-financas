import 'package:flutter/material.dart';

import '../../data/app_data.dart';
import '../../updates/updater.dart';

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
            'Permita que o Tostão instale atualizações na tela que abriu, volte aqui e toque de novo.',
          UpdateStatus.installing => 'Instalando a versão $version…',
          _ => 'A versão $version está pronta.',
        };
        return MaterialBanner(
          leading: const Icon(Icons.system_update),
          content: Text(message),
          actions: [
            FilledButton(
              onPressed: s == UpdateStatus.installing ? null : updater.install,
              child: Text(s == UpdateStatus.permissionRequired ? 'Tentar de novo' : 'Atualizar agora'),
            ),
          ],
        );
      },
    );
  }
}
