import 'package:flutter/material.dart';

import '../../data/app_data.dart';
import '../../sync/sync_controller.dart';
import '../theme/paper.dart';

/// Ajustes → Sincronização (Google Drive).
class SyncCard extends StatelessWidget {
  const SyncCard({super.key});

  @override
  Widget build(BuildContext context) {
    final sync = AppScope.of(context).sync;
    return ListenableBuilder(
      listenable: sync,
      builder: (context, _) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Sincronização', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(width: 8),
                  const SyncDot(),
                ],
              ),
              const SizedBox(height: 6),
              ..._body(context, sync),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _body(BuildContext context, SyncController sync) {
    final p = Paper.of(context);
    if (!sync.configured) {
      return [
        Text(
          'Este build ainda não tem os dados do Google configurados (veja "Sincronização" no README).',
          style: TextStyle(color: p.pencil),
        ),
      ];
    }
    switch (sync.status) {
      case SyncStatus.off:
        return [
          const Text(
            'Os dois aparelhos entram com a mesma conta Google da casa. Os dados vão para uma pasta oculta '
            'do app no Drive, cifrados com uma senha que só vocês sabem: o Google guarda, mas não lê.',
          ),
          if (sync.error != null) _error(context, sync.error!),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: sync.signIn,
            icon: const Icon(Icons.cloud_outlined, size: 18),
            label: const Text('Conectar ao Google Drive'),
          ),
        ];
      case SyncStatus.needsPassphrase:
        return const [_PassphraseForm()];
      case SyncStatus.idle:
      case SyncStatus.syncing:
      case SyncStatus.error:
        final last = sync.lastSync;
        return [
          Text(switch (sync.status) {
            SyncStatus.syncing => 'Sincronizando…',
            SyncStatus.error => 'Não deu para sincronizar agora.',
            _ when last != null => 'Sincronizado às ${_hhmm(last)}. Muda sozinho a cada alteração.',
            _ => 'Conectado.',
          }),
          if (sync.error != null) _error(context, sync.error!),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              FilledButton.icon(
                onPressed: sync.status == SyncStatus.syncing ? null : sync.syncNow,
                icon: const Icon(Icons.sync, size: 18),
                label: const Text('Sincronizar agora'),
              ),
              TextButton(
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('Desconectar?'),
                      content: const Text('Este aparelho para de sincronizar. Os dados continuam aqui e no Drive.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
                        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Desconectar')),
                      ],
                    ),
                  );
                  if (ok == true) await sync.signOut();
                },
                child: const Text('Desconectar'),
              ),
            ],
          ),
        ];
    }
  }

  static String _hhmm(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  static Widget _error(BuildContext context, String e) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Text(e, style: TextStyle(color: Paper.of(context).redInk, fontSize: 13)),
  );
}

class _PassphraseForm extends StatefulWidget {
  const _PassphraseForm();

  @override
  State<_PassphraseForm> createState() => _PassphraseFormState();
}

class _PassphraseFormState extends State<_PassphraseForm> {
  final _pass = TextEditingController();
  final _confirm = TextEditingController();
  bool? _exists; // null = verificando
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final exists = await AppScope.of(context).sync.vaultExistsRemote();
        if (mounted) setState(() => _exists = exists);
      } catch (e) {
        if (mounted) setState(() => _error = '$e');
      }
    });
  }

  Future<void> _submit() async {
    final pass = _pass.text;
    if (pass.length < 8) return setState(() => _error = 'Use pelo menos 8 caracteres.');
    if (_exists == false && pass != _confirm.text) return setState(() => _error = 'As senhas não batem.');
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await AppScope.of(context).sync.unlock(pass);
    if (mounted) {
      setState(() {
        _busy = false;
        _error = err;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Paper.of(context);
    if (_exists == null && _error == null) {
      return const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator());
    }
    final creating = _exists == false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          creating
              ? 'Crie a senha da casa. O outro aparelho vai pedir a mesma. '
                    'Guarde bem: sem ela, os dados do Drive não podem ser lidos (os deste aparelho continuam aqui).'
              : 'Digite a senha da casa, a mesma criada no outro aparelho.',
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: 360,
          child: TextField(
            controller: _pass,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Senha da casa'),
            onSubmitted: (_) => creating ? null : _submit(),
          ),
        ),
        if (creating) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: 360,
            child: TextField(
              controller: _confirm,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Repita a senha'),
              onSubmitted: (_) => _submit(),
            ),
          ),
        ],
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_error!, style: TextStyle(color: p.redInk, fontSize: 13)),
          ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(_busy ? 'Conferindo…' : (creating ? 'Criar e sincronizar' : 'Entrar e sincronizar')),
        ),
      ],
    );
  }
}

/// Bolinha de status: verde sincronizado, âmbar sincronizando, vermelho erro.
class SyncDot extends StatelessWidget {
  const SyncDot({super.key});

  @override
  Widget build(BuildContext context) {
    final sync = AppScope.of(context).sync;
    final p = Paper.of(context);
    return ListenableBuilder(
      listenable: sync,
      builder: (context, _) {
        final (color, tip) = switch (sync.status) {
          SyncStatus.off => (p.pencil.withValues(alpha: 0.4), 'Sincronização desligada'),
          SyncStatus.needsPassphrase => (const Color(0xFFD9A441), 'Falta a senha da casa'),
          SyncStatus.syncing => (const Color(0xFFD9A441), 'Sincronizando…'),
          SyncStatus.idle => (p.greenInk, 'Sincronizado'),
          SyncStatus.error => (p.redInk, sync.error ?? 'Erro na sincronização'),
        };
        return Tooltip(
          message: tip,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        );
      },
    );
  }
}
