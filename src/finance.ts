// Regras de negócio puras (sem banco, sem tela) -> fáceis de testar.
import type { Account, Transaction } from './db';

/** Saldo atual de uma conta, considerando só lançamentos pagos. */
export function accountBalance(account: Account, transactions: Transaction[]): number {
  let balance = account.initialBalance;
  for (const t of transactions) {
    if (t.deletedAt || !t.paid) continue;
    if (t.type === 'receita' && t.accountId === account.id) balance += t.amount;
    if (t.type === 'despesa' && t.accountId === account.id) balance -= t.amount;
    if (t.type === 'transferencia') {
      if (t.accountId === account.id) balance -= t.amount;
      if (t.toAccountId === account.id) balance += t.amount;
    }
  }
  return balance;
}

export interface MonthSummary {
  income: number;
  expense: number;
  balance: number;
  pending: number; // despesas ainda não pagas no mês
  byCategory: Map<string, number>; // despesas por categoria
}

/** Resumo de um mês ("AAAA-MM"). Transferências não contam como receita/despesa. */
export function monthSummary(transactions: Transaction[], month: string): MonthSummary {
  const s: MonthSummary = { income: 0, expense: 0, balance: 0, pending: 0, byCategory: new Map() };
  for (const t of transactions) {
    if (t.deletedAt || !t.date.startsWith(month)) continue;
    if (t.type === 'receita') s.income += t.amount;
    if (t.type === 'despesa') {
      s.expense += t.amount;
      if (!t.paid) s.pending += t.amount;
      const key = t.categoryId ?? 'sem-categoria';
      s.byCategory.set(key, (s.byCategory.get(key) ?? 0) + t.amount);
    }
  }
  s.balance = s.income - s.expense;
  return s;
}
