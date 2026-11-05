import { useLiveQuery } from 'dexie-react-hooks';
import { alive, db } from './db';

// useLiveQuery re-renderiza a tela sozinho sempre que o banco muda.

export const useAccounts = () =>
  useLiveQuery(async () => (await db.accounts.toArray()).filter(alive), []) ?? [];

export const useCategories = () =>
  useLiveQuery(async () => (await db.categories.toArray()).filter(alive).sort((a, b) => a.name.localeCompare(b.name)), []) ?? [];

export const useAllTransactions = () =>
  useLiveQuery(async () => (await db.transactions.toArray()).filter(alive), []) ?? [];

/** Lançamentos de um mês ("AAAA-MM"), mais recentes primeiro. */
export const useMonthTransactions = (month: string) =>
  useLiveQuery(
    async () =>
      (await db.transactions.where('date').between(`${month}-01`, `${month}-31`, true, true).reverse().toArray()).filter(alive),
    [month],
  ) ?? [];
