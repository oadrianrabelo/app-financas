import { useState } from 'react';
import MonthPicker from '../components/MonthPicker';
import { monthOf, today } from '../dates';
import { accountBalance, monthSummary } from '../finance';
import { useAccounts, useAllTransactions, useCategories } from '../hooks';
import { formatBRL } from '../money';

export default function Dashboard() {
  const [month, setMonth] = useState(monthOf(today()));
  const accounts = useAccounts();
  const categories = useCategories();
  const transactions = useAllTransactions();

  const summary = monthSummary(transactions, month);
  const total = accounts.reduce((sum, a) => sum + accountBalance(a, transactions), 0);
  const topCategories = [...summary.byCategory.entries()].sort((a, b) => b[1] - a[1]);
  const max = topCategories[0]?.[1] ?? 1;

  return (
    <>
      <header className="page-header">
        <h1>Início</h1>
        <MonthPicker month={month} onChange={setMonth} />
      </header>

      <section className="card hero">
        <span className="muted">Saldo total nas contas</span>
        <strong className={total < 0 ? 'neg' : ''}>{formatBRL(total)}</strong>
      </section>

      <section className="stats">
        <div className="card stat"><span className="muted">Receitas</span><strong className="pos">{formatBRL(summary.income)}</strong></div>
        <div className="card stat"><span className="muted">Despesas</span><strong className="neg">{formatBRL(summary.expense)}</strong></div>
        <div className="card stat"><span className="muted">Resultado</span><strong className={summary.balance < 0 ? 'neg' : 'pos'}>{formatBRL(summary.balance)}</strong></div>
        <div className="card stat"><span className="muted">A pagar</span><strong>{formatBRL(summary.pending)}</strong></div>
      </section>

      <section className="card">
        <h2>Gastos por categoria</h2>
        {topCategories.length === 0 && <p className="muted">Nenhuma despesa neste mês.</p>}
        {topCategories.map(([id, value]) => {
          const cat = categories.find((c) => c.id === id);
          return (
            <div key={id} className="bar-row">
              <span>{cat ? `${cat.icon} ${cat.name}` : 'Sem categoria'}</span>
              <div className="bar"><div style={{ width: `${(value / max) * 100}%`, background: cat?.color ?? '#64748b' }} /></div>
              <span className="amount">{formatBRL(value)}</span>
            </div>
          );
        })}
      </section>
    </>
  );
}
