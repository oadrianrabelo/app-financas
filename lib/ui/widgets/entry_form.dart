import 'package:flutter/material.dart';

import '../../core/dates.dart';
import '../../core/money.dart';
import '../../data/app_data.dart';
import '../../data/database.dart';

/// Abre o formulário de lançamento (novo ou edição) numa folha de baixo.
Future<void> showEntryForm(BuildContext context, {Entry? editing}) => showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  constraints: const BoxConstraints(maxWidth: 560),
  builder: (_) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: EntryForm(editing: editing),
  ),
);

class EntryForm extends StatefulWidget {
  const EntryForm({super.key, this.editing});
  final Entry? editing;

  @override
  State<EntryForm> createState() => _EntryFormState();
}

class _EntryFormState extends State<EntryForm> {
  late EntryType _type = widget.editing?.type ?? EntryType.despesa;
  late final _amount = TextEditingController(text: widget.editing == null ? '' : centsToInput(widget.editing!.amount));
  late final _description = TextEditingController(text: widget.editing?.description ?? '');
  late String _date = widget.editing?.date ?? today();
  late String? _accountId = widget.editing?.accountId;
  late String? _toAccountId = widget.editing?.toAccountId;
  late String? _categoryId = widget.editing?.categoryId;
  late bool _paid = widget.editing?.paid ?? true;
  String? _error;

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
    await scope.db.saveEntry(
      id: widget.editing?.id,
      type: _type,
      amount: cents!,
      date: _date,
      description: _description.text.trim().isEmpty && transfer ? 'Transferência' : _description.text.trim(),
      accountId: from!,
      toAccountId: transfer ? _toAccountId : null,
      categoryId: transfer ? null : _categoryId,
      paid: _paid,
    );
    if (mounted) Navigator.pop(context);
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
              ButtonSegment(value: EntryType.despesa, label: Text('Despesa')),
              ButtonSegment(value: EntryType.receita, label: Text('Receita')),
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
          if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          gap,
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
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
