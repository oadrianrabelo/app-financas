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
  String? _personId;
  bool _personReady = false;
  bool _recurring = false; // conta fixa (só ao criar)
  bool _variable = false; // conta fixa cujo valor muda (luz)
  int _installments = 1; // parcelas (só ao criar um gasto)
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_personReady) return;
    _personReady = true;
    _personId = widget.editing != null ? widget.editing!.personId : AppScope.of(context).prefs.mePerson;
  }

  bool get _isNew => widget.editing == null;

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
    final description = _description.text.trim();
    final db = scope.db;
    String id;
    if (_isNew && _recurring && !transfer) {
      id = await db.createRecurring(
        type: _type,
        description: description.isEmpty ? scope.data.category(_categoryId)?.name ?? 'Conta fixa' : description,
        amount: cents!,
        variable: _variable,
        day: int.parse(_date.substring(8)),
        accountId: from!,
        categoryId: _categoryId,
        personId: _personId,
        startMonth: monthOf(_date),
      );
      if (_paid) await db.setPaid(id, true);
      if (_type == EntryType.receita && !_tithable) await db.setTitheStatus([id], TitheStatus.isento);
    } else if (_isNew && _installments > 1 && _type == EntryType.despesa) {
      id = await db.saveInstallments(
        installment: cents!,
        count: _installments,
        date: _date,
        description: description,
        accountId: from!,
        categoryId: _categoryId,
        personId: _personId,
        firstPaid: _paid,
      );
    } else {
      id = await db.saveEntry(
        id: widget.editing?.id,
        type: _type,
        amount: cents!,
        date: _date,
        description: description.isEmpty && transfer ? 'Transferência' : description,
        accountId: from!,
        toAccountId: transfer ? _toAccountId : null,
        categoryId: transfer ? null : _categoryId,
        paid: _paid,
        titheStatus: _titheStatus,
        personId: _personId,
      );
    }
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
    // Vale-alimentação só serve para gastos.
    final accounts = data.accounts
        .where((a) => !a.archived || a.id == _accountId)
        .where((a) => _type == EntryType.despesa || a.type != AccountType.vale)
        .toList();
    final from = accounts.any((a) => a.id == _accountId) ? _accountId : accounts.firstOrNull?.id;
    final onVale = data.valeAccountIds.contains(from);
    final editing = widget.editing;
    final rec = data.recurring(editing?.recurringId);
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
            showSelectedIcon: false,
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
            onChanged: (_) => _installments > 1 ? setState(() {}) : null,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Valor', prefixText: r'R$ '),
          ),
          gap,
          TextField(
            controller: _description,
            decoration: const InputDecoration(labelText: 'Descrição', hintText: 'Ex.: Feira do mês'),
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
                  decoration: InputDecoration(labelText: _type == EntryType.transferencia ? 'De' : 'Conta'),
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
              decoration: const InputDecoration(labelText: 'Para'),
              items: [
                for (final a in accounts.where((a) => a.id != from)) DropdownMenuItem(value: a.id, child: Text(a.name)),
              ],
              onChanged: (v) => setState(() => _toAccountId = v),
            )
          else
            DropdownButtonFormField<String?>(
              key: ValueKey(_type),
              initialValue: _categoryId,
              decoration: const InputDecoration(labelText: 'Categoria'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Sem categoria')),
                for (final c in categories) DropdownMenuItem(value: c.id, child: Text('${c.icon} ${c.name}')),
              ],
              onChanged: (v) => setState(() => _categoryId = v),
            ),
          if (onVale)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Pago com o vale-alimentação: não sai do Disponível.',
                style: TextStyle(color: Theme.of(context).colorScheme.secondary),
              ),
            ),
          if (_type != EntryType.transferencia && data.people.isNotEmpty) ...[
            gap,
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text('Quem:'),
                for (final p in data.people)
                  ChoiceChip(
                    label: Text(p.name),
                    selected: _personId == p.id,
                    onSelected: (v) => setState(() => _personId = v ? p.id : null),
                  ),
              ],
            ),
          ],
          if (_isNew && _type != EntryType.transferencia) ...[
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _recurring,
              title: const Text('Conta fixa (repete todo mês)'),
              subtitle: const Text('Ex.: aluguel, internet, salário. Aparece sozinha nos próximos meses.'),
              onChanged: (v) => setState(() {
                _recurring = v ?? false;
                if (_recurring) _installments = 1;
              }),
            ),
            if (_recurring)
              CheckboxListTile(
                contentPadding: const EdgeInsets.only(left: 32),
                controlAffinity: ListTileControlAffinity.leading,
                value: _variable,
                title: const Text('O valor muda todo mês'),
                subtitle: const Text('Ex.: luz. O mês seguinte vem com o valor deste, para você corrigir.'),
                onChanged: (v) => setState(() => _variable = v ?? false),
              ),
          ],
          if (_isNew && _type == EntryType.despesa && !_recurring)
            Row(
              children: [
                const Text('Parcelas:'),
                IconButton(
                  onPressed: _installments > 1 ? () => setState(() => _installments--) : null,
                  icon: const Icon(Icons.remove),
                ),
                Text('$_installments×', style: const TextStyle(fontWeight: FontWeight.w700)),
                IconButton(
                  onPressed: _installments < 48 ? () => setState(() => _installments++) : null,
                  icon: const Icon(Icons.add),
                ),
                if (_installments > 1)
                  Expanded(
                    child: Text(
                      'O valor acima é o de cada parcela'
                      '${parseBRL(_amount.text) != null ? ' (total ${formatBRL(parseBRL(_amount.text)! * _installments)})' : ''}.',
                    ),
                  ),
              ],
            ),
          if (editing?.installmentCount != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Parcela ${editing!.installmentIndex} de ${editing.installmentCount}. A edição vale só para esta.',
              ),
            ),
          if (rec != null)
            Row(
              children: [
                Expanded(
                  child: Text(
                    rec.active
                        ? 'Conta fixa: a edição vale só para este mês.'
                        : 'Conta fixa parada (não aparece nos próximos meses).',
                  ),
                ),
                if (rec.active)
                  TextButton(
                    onPressed: () async {
                      await AppScope.of(context).db.updateRecurring(rec.id, active: false);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(const SnackBar(content: Text('Não vai mais repetir nos próximos meses.')));
                      }
                    },
                    child: const Text('Parar de repetir'),
                  ),
              ],
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
