import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../backup/backup.dart';
import '../../core/money.dart';
import '../../core/dates.dart';
import '../../data/app_data.dart';
import '../../data/database.dart';
import '../../domain/tithe.dart';
import '../../updates/updater.dart';
import '../theme/fonts.dart';
import '../theme/paper.dart';
import '../widgets/common.dart';
import '../widgets/sync_card.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PageBody(
      title: 'Ajustes',
      children: [
        SyncCard(),
        _TitheCard(),
        _RecurringCard(),
        _PeopleCard(),
        _LookCard(),
        _BackupCard(),
        _UpdatesCard(),
        _CategoriesCard(),
      ],
    );
  }
}

void _toast(BuildContext context, String msg) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

class _TitheCard extends StatelessWidget {
  const _TitheCard();

  @override
  Widget build(BuildContext context) {
    final prefs = AppScope.of(context).prefs;
    Widget field(String label, int bp, Future<void> Function(int) save) =>
        _PercentField(label: label, bp: bp, onSave: save);
    return ListenableBuilder(
      listenable: prefs,
      builder: (context, _) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Dízimo e oferta', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              const Text(
                'Valores sugeridos no botão "Separar dízimo e oferta". Ao separar, dá para ajustar na hora; '
                'o percentual da oferta usado fica lembrado para a próxima vez.',
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                children: [
                  field('Dízimo', prefs.titheBp, prefs.setTitheBp),
                  field('Oferta', prefs.offeringBp, prefs.setOfferingBp),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Campo de percentual que salva ao sair do campo (ou Enter), sem perder o foco.
class _PercentField extends StatefulWidget {
  const _PercentField({required this.label, required this.bp, required this.onSave});
  final String label;
  final int bp;
  final Future<void> Function(int) onSave;

  @override
  State<_PercentField> createState() => _PercentFieldState();
}

class _PercentFieldState extends State<_PercentField> {
  late final _controller = TextEditingController(text: _text(widget.bp));
  final _focus = FocusNode();

  static String _text(int bp) => formatBp(bp).replaceAll('%', '');

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _save();
    });
  }

  @override
  void didUpdateWidget(_PercentField old) {
    super.didUpdateWidget(old);
    if (!_focus.hasFocus && old.bp != widget.bp) _controller.text = _text(widget.bp);
  }

  void _save() {
    final bp = parseBp(_controller.text);
    if (bp == null) {
      _controller.text = _text(widget.bp);
    } else if (bp != widget.bp) {
      widget.onSave(bp);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 150,
    child: TextField(
      controller: _controller,
      focusNode: _focus,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: widget.label, suffixText: '%'),
      onSubmitted: (_) => _save(),
      onTapOutside: (_) => _focus.unfocus(),
    ),
  );
}

class _RecurringCard extends StatelessWidget {
  const _RecurringCard();

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return ListenableBuilder(
      listenable: scope.data,
      builder: (context, _) {
        final list = scope.data.recurrings;
        return Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                title: Text('Contas fixas', style: Theme.of(context).textTheme.titleMedium),
                subtitle: const Text(
                  'Aparecem sozinhas todo mês para marcar ✓. Para criar, marque "Conta fixa" ao lançar.',
                ),
              ),
              if (list.isEmpty) const ListTile(title: Text('Nenhuma ainda.')),
              for (final r in list)
                ListTile(
                  enabled: r.active,
                  title: Text(r.description),
                  subtitle: Text(
                    [
                      r.type == EntryType.receita ? 'Entrada' : 'Gasto',
                      'dia ${r.day}',
                      r.variable ? 'valor muda (repete o do mês anterior)' : formatBRL(r.amount),
                      if (!r.active) 'parada',
                    ].join(' · '),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: r.variable ? 'Valor fixo' : 'O valor muda todo mês',
                        icon: Icon(r.variable ? Icons.trending_flat : Icons.show_chart),
                        onPressed: r.active ? () => scope.db.updateRecurring(r.id, variable: !r.variable) : null,
                      ),
                      IconButton(
                        tooltip: r.active ? 'Parar de repetir' : 'Voltar a repetir',
                        icon: Icon(r.active ? Icons.pause_circle_outline : Icons.play_circle_outline),
                        onPressed: () => scope.db.updateRecurring(r.id, active: !r.active),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _PeopleCard extends StatelessWidget {
  const _PeopleCard();

  Future<void> _rename(BuildContext context, Person person) async {
    final controller = TextEditingController(text: person.name);
    final name = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Nome'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(c, controller.text.trim()), child: const Text('Salvar')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty && context.mounted) await AppScope.of(context).db.renamePerson(person.id, name);
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([scope.data, scope.prefs]),
      builder: (context, _) => Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              title: Text('Pessoas da casa', style: Theme.of(context).textTheme.titleMedium),
              subtitle: const Text('Escolha de quem é este aparelho: é quem vem marcado ao lançar.'),
            ),
            for (final p in scope.data.people)
              RadioListTile<String>(
                value: p.id,
                // ignore: deprecated_member_use
                groupValue: scope.prefs.mePerson,
                // ignore: deprecated_member_use
                onChanged: (v) => scope.prefs.setMePerson(v!),
                title: Text(p.name),
                subtitle: scope.prefs.mePerson == p.id ? const Text('Este aparelho') : null,
                secondary: IconButton(
                  tooltip: 'Trocar o nome',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _rename(context, p),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LookCard extends StatelessWidget {
  const _LookCard();

  @override
  Widget build(BuildContext context) {
    final prefs = AppScope.of(context).prefs;
    final p = Paper.of(context);
    return ListenableBuilder(
      listenable: prefs,
      builder: (context, _) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Aparência', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              SegmentedButton<ThemeMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: ThemeMode.system, label: Text('Automático')),
                  ButtonSegment(value: ThemeMode.light, label: Text('Papel')),
                  ButtonSegment(value: ThemeMode.dark, label: Text('Noite')),
                ],
                selected: {prefs.themeMode},
                onSelectionChanged: (v) => prefs.setThemeMode(v.first),
              ),
              const SizedBox(height: 16),
              const Text('Letra de mão'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final f in handFonts)
                    ChoiceChip(
                      label: Text('Setembro', style: p.copyWith(handFont: f).hand(22)),
                      tooltip: f,
                      selected: prefs.handFont == f,
                      onSelected: (_) => prefs.setHandFont(f),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Números'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final f in monoFonts)
                    ChoiceChip(
                      label: Text(r'R$ 1.234,56', style: p.copyWith(monoFont: f).mono(15)),
                      tooltip: f,
                      selected: prefs.monoFont == f,
                      onSelected: (_) => prefs.setMonoFont(f),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
                subtitle: Text(
                  c.kind == CategoryKind.receita ? 'Entrada' : 'Gasto · ${_sectionLabels[c.section] ?? 'Outros'}',
                ),
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
  CategorySection _section = CategorySection.casa;

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
              DropdownMenuItem(value: CategoryKind.despesa, child: Text('Gasto')),
              DropdownMenuItem(value: CategoryKind.receita, child: Text('Entrada')),
            ],
            onChanged: (v) => setState(() => _kind = v!),
          ),
          if (_kind == CategoryKind.despesa)
            DropdownButtonFormField(
              initialValue: _section,
              decoration: const InputDecoration(labelText: 'Seção no caderno'),
              items: [
                for (final s in [
                  CategorySection.cartao,
                  CategorySection.casa,
                  CategorySection.pessoal,
                  CategorySection.outros,
                ])
                  DropdownMenuItem(value: s, child: Text(_sectionLabels[s]!)),
              ],
              onChanged: (v) => setState(() => _section = v!),
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
            await AppScope.of(context).db.addCategory(
              name: _name.text.trim(),
              kind: _kind,
              icon: _icon.text.trim(),
              color: color,
              section: _kind == CategoryKind.despesa ? _section : null,
            );
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Adicionar'),
        ),
      ],
    );
  }
}

const _sectionLabels = {
  CategorySection.primicias: 'Dízimo e oferta',
  CategorySection.cartao: 'Cartão',
  CategorySection.casa: 'Casa',
  CategorySection.pessoal: 'Pessoal',
  CategorySection.outros: 'Outros',
};
