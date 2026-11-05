import { useState, type FormEvent } from 'react';
import { create, update, type Transaction, type TransactionType } from '../db';
import { useAccounts, useCategories } from '../hooks';
import { centsToInput, parseBRL } from '../money';
import { today } from '../dates';

interface Props {
  editing?: Transaction;
  onDone: () => void;
}

export default function TransactionForm({ editing, onDone }: Props) {
  const accounts = useAccounts().filter((a) => !a.archived);
  const categories = useCategories();

  const [type, setType] = useState<TransactionType>(editing?.type ?? 'despesa');
  const [amount, setAmount] = useState(editing ? centsToInput(editing.amount) : '');
  const [description, setDescription] = useState(editing?.description ?? '');
  const [date, setDate] = useState(editing?.date ?? today());
  const [accountId, setAccountId] = useState(editing?.accountId ?? '');
  const [toAccountId, setToAccountId] = useState(editing?.toAccountId ?? '');
  const [categoryId, setCategoryId] = useState(editing?.categoryId ?? '');
  const [paid, setPaid] = useState(editing?.paid ?? true);
  const [error, setError] = useState('');

  const visibleCategories = categories.filter((c) => c.kind === type);
  const fromAccount = accountId || accounts[0]?.id || '';

  async function submit(e: FormEvent) {
    e.preventDefault();
    const cents = parseBRL(amount);
    if (!cents || cents <= 0) return setError('Informe um valor maior que zero.');
    if (!fromAccount) return setError('Crie uma conta primeiro.');
    if (type === 'transferencia' && (!toAccountId || toAccountId === fromAccount)) {
      return setError('Escolha uma conta de destino diferente.');
    }

    const data = {
      type,
      amount: cents,
      description: description.trim() || (type === 'transferencia' ? 'Transferência' : ''),
      date,
      accountId: fromAccount,
      toAccountId: type === 'transferencia' ? toAccountId : undefined,
      categoryId: type === 'transferencia' ? undefined : categoryId || undefined,
      paid,
    };
    if (editing) await update<Transaction>('transactions', editing.id, data);
    else await create<Transaction>('transactions', data);
    onDone();
  }

  return (
    <form className="card form" onSubmit={submit}>
      <div className="segmented">
        {(['despesa', 'receita', 'transferencia'] as const).map((t) => (
          <button type="button" key={t} className={type === t ? `active ${t}` : ''} onClick={() => { setType(t); setCategoryId(''); }}>
            {{ despesa: 'Despesa', receita: 'Receita', transferencia: 'Transferência' }[t]}
          </button>
        ))}
      </div>

      <label>
        Valor
        <input inputMode="decimal" placeholder="0,00" value={amount} onChange={(e) => setAmount(e.target.value)} autoFocus />
      </label>
      <label>
        Descrição
        <input placeholder="Ex.: Feira do mês" value={description} onChange={(e) => setDescription(e.target.value)} />
      </label>
      <div className="row">
        <label>
          Data
          <input type="date" value={date} onChange={(e) => setDate(e.target.value)} required />
        </label>
        <label>
          {type === 'transferencia' ? 'De' : 'Conta'}
          <select value={fromAccount} onChange={(e) => setAccountId(e.target.value)}>
            {accounts.map((a) => <option key={a.id} value={a.id}>{a.name}</option>)}
          </select>
        </label>
      </div>

      {type === 'transferencia' ? (
        <label>
          Para
          <select value={toAccountId} onChange={(e) => setToAccountId(e.target.value)}>
            <option value="">Selecione…</option>
            {accounts.filter((a) => a.id !== fromAccount).map((a) => <option key={a.id} value={a.id}>{a.name}</option>)}
          </select>
        </label>
      ) : (
        <label>
          Categoria
          <select value={categoryId} onChange={(e) => setCategoryId(e.target.value)}>
            <option value="">Sem categoria</option>
            {visibleCategories.map((c) => <option key={c.id} value={c.id}>{c.icon} {c.name}</option>)}
          </select>
        </label>
      )}

      <label className="check">
        <input type="checkbox" checked={paid} onChange={(e) => setPaid(e.target.checked)} />
        {type === 'receita' ? 'Já recebido' : 'Já pago'}
      </label>

      {error && <p className="error">{error}</p>}
      <div className="actions">
        <button type="button" className="ghost" onClick={onDone}>Cancelar</button>
        <button type="submit">{editing ? 'Salvar' : 'Adicionar'}</button>
      </div>
    </form>
  );
}
