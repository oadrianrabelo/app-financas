import 'package:flutter/material.dart';

import '../../core/dates.dart';
import '../../core/money.dart';
import '../../data/app_data.dart';
import '../../data/database.dart';
import 'common.dart';
import 'tithe_dialog.dart';

/// Abre o formulário de lançamento (novo ou edição) numa folha de baixo.
/// Depois de salvar uma ENTRADA, pergunta se quer separar dízimo e oferta.
Future<void> showEntryForm(BuildContext context, {Entry? editing, EntryType? type, String? date}) async {
  final before = editing;
  final savedId = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (_) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: EntryForm(editing: editing, initialType: type, initialDate: date),
    ),
  );
  if (savedId == null || !context.mounted) return;
  final db = AppScope.of(context).db;
  final saved = await db.getEntry(savedId);
  if (saved == null || saved.type != EntryType.receita || !context.mounted) return;

  if (saved.titheStatus == TitheStatus.pendente && (before == null || before.titheStatus != TitheStatus.pendente)) {
    await showTitheDialog(context, incomes: [saved]);
  } else if (before != null && saved.titheStatus == TitheStatus.separado && saved.amount != before.amount) {
    final diff = saved.amount - before.amount;
    if (diff > 0) {
      await showTitheDialog(context, incomes: [saved], base: diff);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Esta entrada já teve o dízimo separado. Se precisar, ajuste o dízimo e a oferta do mês.'),
        ),
      );
    }
  }
}

class EntryForm extends StatefulWidget {
  const EntryForm({super.key, this.editing, this.initialType, this.initialDate});
  final Entry? editing;
  final EntryType? initialType;
  final String? initialDate;

  @override
  State<EntryForm> createState() => _EntryFormState();
}

class _EntryFormState extends State<EntryForm> {
  late EntryType _type = widget.editing?.type ?? widget.initialType ?? EntryType.despesa;
  late final _amount = TextEditingController(text: widget.editing == null ? '' : centsToInput(widget.editing!.amount));
  late final _description = TextEditingController(text: widget.editing?.description ?? '');
  late String _date = widget.editing?.date ?? widget.initialDate ?? today();
  late String? _accountId = widget.editing?.accountId;
  late String? _toAccountId = widget.editing?.toAccountId;
  late String? _categoryId = widget.editing?.categoryId;
  late bool _paid = widget.editing?.paid ?? true;
  late bool _tithable = widget.editing?.titheStatus != TitheStatus.isento;
  String? _error;

  /// Situação do dízimo a gravar (só para entradas).
  TitheStatus? get _titheStatus {
    if (_type != EntryType.receita) return null;
    if (!_tithable) return TitheStatus.isento;
    final old = widget.editing?.titheStatus;
    return old == TitheStatus.separado ? null : TitheStatus.pendente; // null = mantém "separado"
  }

  Future<void> _delete() async {
    final e = widget.editing!;
    final warn = e.titheStatus == TitheStatus.separado
        ? '\n\nEsta entrada já teve dízimo e oferta separados; eles continuam lançados.'
        : '';
    if (!await confirm(context, 'Excluir "${e.description.isEmpty ? 'este lançamento' : e.description}"?$warn')) return;
    if (!mounted) return;
    final db = AppScope.of(context).db;
    await db.softDelete(db.entries, e.id);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _save() async {
    final scope = AppScope.of(context);
    final accounts = scope.data.accounts.where((a) => !a.archived).toList();
    final from = _accountId ?? accounts.firstOrNull?.id;
    final cents = parseBRL(_amount.text);
    String? error;
    if (cents == null || cents <= 0) error = 'Informe um valor maior que zero.';
    if (from == null) error = 'Crie uma conta primeiro.';
    if (_type == EntryType.transferencia && (_toAccountId == null || _toAccountId == from)) {
      error = 'Escolha uma conta de destino diferente.';
    }
    if (error != null) return setState(() => _error = error);

    final transfer = _type == EntryType.transferencia;
    final id = await scope.db.saveEntry(
      id: widget.editing?.id,
      type: _type,
      amount: cents!,
      date: _date,
      description: _description.text.trim().isEmpty && transfer ? 'Transferência' : _description.text.trim(),
      accountId: from!,
      toAccountId: transfer ? _toAccountId : null,
      categoryId: transfer ? null : _categoryId,
      paid: _paid,
      titheStatus: _titheStatus,
    );
    if (mounted) Navigator.pop(context, id);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.parse(_date),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = toIsoDate(picked));
  }

  @override
  Widget build(BuildContext context) {
    final data = AppScope.of(context).data;
    final accounts = data.accounts.where((a) => !a.archived || a.id == _accountId).toList();
    final from = _accountId ?? accounts.firstOrNull?.id;
    final kind = _type == EntryType.receita ? CategoryKind.receita : CategoryKind.despesa;
    final categories = data.categories.where((c) => c.kind == kind).toList();
    const gap = SizedBox(height: 12);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          SegmentedButton<EntryType>(
            segments: const [
              ButtonSegment(value: EntryType.despesa, label: Text('Gasto')),
              ButtonSegment(value: EntryType.receita, label: Text('Entrada')),
              ButtonSegment(value: EntryType.transferencia, label: Text('Transferência')),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() {
              _type = s.first;
              _categoryId = null;
            }),
          ),
          gap,
          TextField(
            controller: _amount,
            autofocus: widget.editing == null,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Valor', prefixText: r'R$ ', border: OutlineInputBorder()),
          ),
          gap,
          TextField(
            controller: _description,
            decoration: const InputDecoration(
              labelText: 'Descrição',
              hintText: 'Ex.: Feira do mês',
              border: OutlineInputBorder(),
            ),
          ),
          gap,
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: Text(formatDate(_date)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: from,
                  decoration: InputDecoration(
                    labelText: _type == EntryType.transferencia ? 'De' : 'Conta',
                    border: const OutlineInputBorder(),
                  ),
                  items: [for (final a in accounts) DropdownMenuItem(value: a.id, child: Text(a.name))],
                  onChanged: (v) => setState(() => _accountId = v),
                ),
              ),
            ],
          ),
          gap,
          if (_type == EntryType.transferencia)
            DropdownButtonFormField<String>(
              initialValue: _toAccountId,
              decoration: const InputDecoration(labelText: 'Para', border: OutlineInputBorder()),
              items: [
                for (final a in accounts.where((a) => a.id != from)) DropdownMenuItem(value: a.id, child: Text(a.name)),
              ],
              onChanged: (v) => setState(() => _toAccountId = v),
            )
          else
            DropdownButtonFormField<String?>(
              key: ValueKey(_type),
              initialValue: _categoryId,
              decoration: const InputDecoration(labelText: 'Categoria', border: OutlineInputBorder()),
              items: [
                const DropdownMenuItem(value: null, child: Text('Sem categoria')),
                for (final c in categories) DropdownMenuItem(value: c.id, child: Text('${c.icon} ${c.name}')),
              ],
              onChanged: (v) => setState(() => _categoryId = v),
            ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _paid,
            title: Text(_type == EntryType.receita ? 'Já recebido' : 'Já pago'),
            onChanged: (v) => setState(() => _paid = v ?? true),
          ),
          if (_type == EntryType.receita)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _tithable,
              title: const Text('Gera dízimo e oferta'),
              subtitle: Text(
                widget.editing?.titheStatus == TitheStatus.separado
                    ? 'Já separado'
                    : 'Desmarque para dinheiro que só está voltando (ex.: empréstimo).',
              ),
              onChanged: (v) => setState(() => _tithable = v ?? true),
            ),
          if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          gap,
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (widget.editing != null) ...[
                TextButton.icon(
                  onPressed: _delete,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Excluir'),
                  style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                ),
                const Spacer(),
              ],
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
              const SizedBox(width: 8),
              FilledButton(onPressed: _save, child: Text(widget.editing == null ? 'Adicionar' : 'Salvar')),
            ],
          ),
        ],
      ),
    );
  }
}
