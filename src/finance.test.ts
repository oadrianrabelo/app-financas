import { describe, expect, it } from 'vitest';
import type { Account, Transaction } from './db';
import { accountBalance, monthSummary } from './finance';

const base = { createdAt: 0, updatedAt: 0 };
const acc = (id: string, initialBalance = 0): Account => ({ ...base, id, name: id, type: 'corrente', initialBalance });
let n = 0;
const tx = (t: Partial<Transaction>): Transaction => ({
  ...base,
  id: String(n++),
  type: 'despesa',
  amount: 0,
  date: '2026-11-01',
  description: '',
  accountId: 'a',
  paid: true,
  ...t,
});

describe('accountBalance', () => {
  it('soma receitas, subtrai despesas e trata transferências', () => {
    const list = [
      tx({ type: 'receita', amount: 500000 }),
      tx({ type: 'despesa', amount: 12050 }),
      tx({ type: 'transferencia', amount: 100000, toAccountId: 'b' }),
      tx({ type: 'despesa', amount: 999, paid: false }), // não pago: ignora
      tx({ type: 'despesa', amount: 999, deletedAt: 1 }), // apagado: ignora
    ];
    expect(accountBalance(acc('a', 1000), list)).toBe(1000 + 500000 - 12050 - 100000);
    expect(accountBalance(acc('b'), list)).toBe(100000);
  });
});

describe('monthSummary', () => {
  it('resume o mês e agrupa por categoria', () => {
    const list = [
      tx({ type: 'receita', amount: 300000 }),
      tx({ type: 'despesa', amount: 1000, categoryId: 'mercado' }),
      tx({ type: 'despesa', amount: 2000, categoryId: 'mercado', paid: false }),
      tx({ type: 'despesa', amount: 5000, date: '2026-10-31' }), // outro mês
      tx({ type: 'transferencia', amount: 7000, toAccountId: 'b' }),
    ];
    const s = monthSummary(list, '2026-11');
    expect(s.income).toBe(300000);
    expect(s.expense).toBe(3000);
    expect(s.balance).toBe(297000);
    expect(s.pending).toBe(2000);
    expect(s.byCategory.get('mercado')).toBe(3000);
  });
});
