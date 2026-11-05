import { useState, type FormEvent } from 'react';
import { create, softDelete, update, type Account, type AccountType } from '../db';
import { accountBalance } from '../finance';
import { useAccounts, useAllTransactions } from '../hooks';
import { formatBRL, parseBRL } from '../money';

const TYPES: Record<AccountType, string> = {
  corrente: '🏦 Conta corrente',
  poupanca: '🐷 Poupança',
  carteira: '👛 Carteira',
  cartao: '💳 Cartão de crédito',
  investimento: '📈 Investimento',
};

export default function Accounts() {
  const accounts = useAccounts();
  const transactions = useAllTransactions();
  const [name, setName] = useState('');
  const [type, setType] = useState<AccountType>('corrente');
  const [initial, setInitial] = useState('');

  async function add(e: FormEvent) {
    e.preventDefault();
    if (!name.trim()) return;
    await create<Account>('accounts', { name: name.trim(), type, initialBalance: parseBRL(initial) ?? 0 });
    setName('');
    setInitial('');
  }

  async function remove(a: Account) {
    const used = transactions.some((t) => t.accountId === a.id || t.toAccountId === a.id);
    if (used) {
      if (confirm(`"${a.name}" tem lançamentos. Arquivar a conta em vez de excluir?`)) {
        await update<Account>('accounts', a.id, { archived: true });
      }
    } else if (confirm(`Excluir "${a.name}"?`)) {
      await softDelete('accounts', a.id);
    }
  }

  return (
    <>
      <header className="page-header"><h1>Contas</h1></header>

      <ul className="list card">
        {accounts.map((a) => {
          const balance = accountBalance(a, transactions);
          return (
            <li key={a.id} className={a.archived ? 'pending' : ''}>
              <span className="tx-main">
                <strong>{a.name}{a.archived && ' (arquivada)'}</strong>
                <small className="muted">{TYPES[a.type]}</small>
              </span>
              <span className={`amount ${balance < 0 ? 'despesa' : ''}`}>{formatBRL(balance)}</span>
              <div className="tx-actions">
                {a.archived
                  ? <button className="ghost" title="Desarquivar" onClick={() => update<Account>('accounts', a.id, { archived: false })}>↩️</button>
                  : <button className="ghost" title="Excluir / arquivar" onClick={() => remove(a)}>🗑️</button>}
              </div>
            </li>
          );
        })}
      </ul>

      <form className="card form" onSubmit={add}>
        <h2>Nova conta</h2>
        <label>Nome<input value={name} onChange={(e) => setName(e.target.value)} placeholder="Ex.: Nubank" /></label>
        <div className="row">
          <label>
            Tipo
            <select value={type} onChange={(e) => setType(e.target.value as AccountType)}>
              {Object.entries(TYPES).map(([k, v]) => <option key={k} value={k}>{v}</option>)}
            </select>
          </label>
          <label>Saldo inicial<input inputMode="decimal" value={initial} onChange={(e) => setInitial(e.target.value)} placeholder="0,00" /></label>
        </div>
        <div className="actions"><button type="submit">Adicionar conta</button></div>
      </form>
    </>
  );
}
