import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../backup/backup.dart';
import '../../core/dates.dart';
import '../../data/app_data.dart';
import '../../data/database.dart';
import '../../updates/updater.dart';
import '../widgets/common.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PageBody(title: 'Ajustes', children: [_BackupCard(), _UpdatesCard(), _CategoriesCard()]);
  }
}

void _toast(BuildContext context, String msg) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

class _BackupCard extends StatelessWidget {
  const _BackupCard();

  Future<void> _export(BuildContext context) async {
    final db = AppScope.of(context).db;
    final json = const JsonEncoder.withIndent('  ').convert(await exportData(db));
    final saved = await FilePicker.saveFile(
      fileName: 'livro-caixa-backup-${today()}.json',
      bytes: Uint8List.fromList(utf8.encode(json)),
      mimeType: 'application/json',
    );
    if (saved != null && context.mounted) _toast(context, 'Backup salvo.');
  }

  Future<void> _import(BuildContext context) async {
    final db = AppScope.of(context).db;
    final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['json']);
    if (file == null) return;
    try {
      final result = await importData(db, jsonDecode(utf8.decode(await file.readAsBytes())));
      if (context.mounted) _toast(context, 'Importado: $result.');
    } on FormatException catch (e) {
      if (context.mounted) _toast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Backup e sincronização', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text(
              'Seus dados ficam só neste aparelho. Exporte um backup com frequência. Para levar os dados a outro '
              'aparelho, exporte aqui e importe lá: a importação junta tudo e mantém a versão mais recente de cada item.',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _import(context),
                  icon: const Icon(Icons.file_open_outlined),
                  label: const Text('Importar…'),
                ),
                FilledButton.icon(
                  onPressed: () => _export(context),
                  icon: const Icon(Icons.save_alt),
                  label: const Text('Exportar backup'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _UpdatesCard extends StatelessWidget {
  const _UpdatesCard();

  @override
  Widget build(BuildContext context) {
    final updater = AppScope.of(context).updater;
    return ListenableBuilder(
      listenable: updater,
      builder: (context, _) {
        final status = switch (updater.status) {
          UpdateStatus.idle || UpdateStatus.checking => 'Procurando…',
          UpdateStatus.upToDate => 'Você está na versão mais recente.',
          UpdateStatus.downloading =>
            'Baixando a versão ${updater.available?.version}'
                '${updater.progress != null ? ' (${(updater.progress! * 100).round()}%)' : ''}…',
          UpdateStatus.ready ||
          UpdateStatus.permissionRequired => 'Versão ${updater.available?.version} pronta para instalar.',
          UpdateStatus.installing => 'Instalando…',
          UpdateStatus.unsupported => updater.error ?? 'Atualização automática desligada nesta versão (build local).',
          UpdateStatus.error => 'Não deu para verificar: ${updater.error}',
        };
        return Card(
          child: ListTile(
            leading: const Icon(Icons.system_update_outlined),
            title: Text('Versão ${updater.currentVersion}'),
            subtitle: Text(status),
            trailing: updater.status == UpdateStatus.ready
                ? FilledButton(onPressed: updater.install, child: const Text('Atualizar'))
                : IconButton(tooltip: 'Procurar agora', icon: const Icon(Icons.refresh), onPressed: updater.check),
          ),
        );
      },
    );
  }
}

class _CategoriesCard extends StatelessWidget {
  const _CategoriesCard();

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return ListenableBuilder(
      listenable: scope.data,
      builder: (context, _) => Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              title: Text('Categorias', style: Theme.of(context).textTheme.titleMedium),
              trailing: TextButton.icon(
                onPressed: () => showDialog(context: context, builder: (_) => const _NewCategoryDialog()),
                icon: const Icon(Icons.add),
                label: const Text('Nova'),
              ),
            ),
            for (final c in scope.data.categories)
              ListTile(
                leading: Text(c.icon, style: const TextStyle(fontSize: 22)),
                title: Text(c.name),
                subtitle: Text(c.kind == CategoryKind.despesa ? 'Despesa' : 'Receita'),
                trailing: IconButton(
                  tooltip: 'Excluir',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    if (await confirm(context, 'Excluir "${c.name}"?')) {
                      await scope.db.softDelete(scope.db.categories, c.id);
                    }
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NewCategoryDialog extends StatefulWidget {
  const _NewCategoryDialog();

  @override
  State<_NewCategoryDialog> createState() => _NewCategoryDialogState();
}

class _NewCategoryDialogState extends State<_NewCategoryDialog> {
  final _name = TextEditingController();
  final _icon = TextEditingController(text: '🏷️');
  CategoryKind _kind = CategoryKind.despesa;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nova categoria'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _icon,
            decoration: const InputDecoration(labelText: 'Ícone (emoji)'),
          ),
          TextField(
            controller: _name,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Nome', hintText: 'Ex.: Pets'),
          ),
          DropdownButtonFormField(
            initialValue: _kind,
            decoration: const InputDecoration(labelText: 'Tipo'),
            items: const [
              DropdownMenuItem(value: CategoryKind.despesa, child: Text('Despesa')),
              DropdownMenuItem(value: CategoryKind.receita, child: Text('Receita')),
            ],
            onChanged: (v) => setState(() => _kind = v!),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () async {
            if (_name.text.trim().isEmpty) return;
            final color = HSLColor.fromAHSL(
              1,
              (DateTime.now().millisecond * 0.36) % 360,
              0.65,
              0.45,
            ).toColor().toARGB32();
            await AppScope.of(context).db
                .addCategory(name: _name.text.trim(), kind: _kind, icon: _icon.text.trim(), color: color);
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Adicionar'),
        ),
      ],
    );
  }
}
