import { useState } from 'react';
import MonthPicker from '../components/MonthPicker';
import TransactionForm from '../components/TransactionForm';
import { softDelete, update, type Transaction } from '../db';
import { formatDate, monthOf, today } from '../dates';
import { useAccounts, useCategories, useMonthTransactions } from '../hooks';
import { formatBRL } from '../money';

export default function Transactions() {
  const [month, setMonth] = useState(monthOf(today()));
  const [editing, setEditing] = useState<Transaction | 'new' | null>(null);
  const [search, setSearch] = useState('');
  const transactions = useMonthTransactions(month);
  const accounts = useAccounts();
  const categories = useCategories();

  const filtered = transactions.filter((t) => t.description.toLowerCase().includes(search.toLowerCase()));
  const accountName = (id?: string) => accounts.find((a) => a.id === id)?.name ?? '—';

  return (
    <>
      <header className="page-header">
        <h1>Lançamentos</h1>
        <MonthPicker month={month} onChange={setMonth} />
      </header>

      {editing ? (
        <TransactionForm editing={editing === 'new' ? undefined : editing} onDone={() => setEditing(null)} />
      ) : (
        <div className="toolbar">
          <input placeholder="Buscar…" value={search} onChange={(e) => setSearch(e.target.value)} />
          <button onClick={() => setEditing('new')}>+ Novo</button>
        </div>
      )}

      <ul className="list card">
        {filtered.length === 0 && <li className="muted">Nada por aqui.</li>}
        {filtered.map((t) => {
          const cat = categories.find((c) => c.id === t.categoryId);
          const sign = t.type === 'receita' ? '+' : t.type === 'despesa' ? '−' : '⇄';
          return (
            <li key={t.id} className={t.paid ? '' : 'pending'}>
              <span className="tx-icon">{t.type === 'transferencia' ? '🔁' : cat?.icon ?? '•'}</span>
              <button className="tx-main ghost" onClick={() => setEditing(t)}>
                <strong>{t.description || cat?.name || 'Sem descrição'}</strong>
                <small className="muted">
                  {formatDate(t.date)} · {accountName(t.accountId)}
                  {t.type === 'transferencia' && ` → ${accountName(t.toAccountId)}`}
                  {!t.paid && ' · pendente'}
                </small>
              </button>
              <span className={`amount ${t.type}`}>{sign} {formatBRL(t.amount)}</span>
              <div className="tx-actions">
                {!t.paid && <button className="ghost" title="Marcar como pago" onClick={() => update<Transaction>('transactions', t.id, { paid: true })}>✔️</button>}
                <button className="ghost" title="Excluir" onClick={() => confirm('Excluir este lançamento?') && softDelete('transactions', t.id)}>🗑️</button>
              </div>
            </li>
          );
        })}
      </ul>
    </>
  );
}
