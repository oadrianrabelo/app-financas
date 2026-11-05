import Dexie, { type EntityTable } from 'dexie';

// ---------------------------------------------------------------------------
// Modelo de dados
//
// Regras que deixam o app pronto para sincronizar entre aparelhos no futuro:
//  - IDs são UUIDs (texto), gerados no próprio aparelho -> sem colisão entre
//    o seu celular e o da sua esposa.
//  - Todo registro tem `updatedAt` -> numa mesclagem, a versão mais nova vence.
//  - Nada é apagado de verdade: marcamos `deletedAt` ("lápide"). Assim a
//    exclusão também se propaga quando os dados forem mesclados.
// ---------------------------------------------------------------------------

export interface BaseRecord {
  id: string;
  createdAt: number; // Date.now()
  updatedAt: number;
  deletedAt?: number;
}

export type AccountType = 'corrente' | 'poupanca' | 'carteira' | 'cartao' | 'investimento';

export interface Account extends BaseRecord {
  name: string;
  type: AccountType;
  initialBalance: number; // centavos
  archived?: boolean;
}

export type CategoryKind = 'despesa' | 'receita';

export interface Category extends BaseRecord {
  name: string;
  kind: CategoryKind;
  icon: string; // emoji
  color: string; // hex
}

export type TransactionType = 'despesa' | 'receita' | 'transferencia';

export interface Transaction extends BaseRecord {
  type: TransactionType;
  amount: number; // centavos, sempre positivo; o `type` diz o sinal
  date: string; // AAAA-MM-DD
  description: string;
  accountId: string; // conta de origem
  toAccountId?: string; // só para transferências
  categoryId?: string; // não usado em transferências
  paid: boolean; // false = agendado / ainda não pago
  notes?: string;
}

export interface Budget extends BaseRecord {
  categoryId: string;
  month: string; // AAAA-MM
  limit: number; // centavos
}

export class FinancasDB extends Dexie {
  accounts!: EntityTable<Account, 'id'>;
  categories!: EntityTable<Category, 'id'>;
  transactions!: EntityTable<Transaction, 'id'>;
  budgets!: EntityTable<Budget, 'id'>;

  constructor(name = 'tostao') {
    super(name);
    // Só liste aqui os campos que você vai usar em consultas (índices).
    // Ao mudar o esquema, NÃO edite a versão 1: crie `this.version(2)...`.
    this.version(1).stores({
      accounts: 'id, updatedAt',
      categories: 'id, kind, updatedAt',
      transactions: 'id, date, accountId, toAccountId, categoryId, updatedAt',
      budgets: 'id, [categoryId+month], month, updatedAt',
    });

    this.on('populate', (tx) => {
      const now = Date.now();
      const base = () => ({ id: crypto.randomUUID(), createdAt: now, updatedAt: now });
      tx.table('accounts').add({ ...base(), name: 'Carteira', type: 'carteira', initialBalance: 0 });
      tx.table('categories').bulkAdd(
        DEFAULT_CATEGORIES.map(([name, kind, icon, color]) => ({ ...base(), name, kind, icon, color })),
      );
    });
  }
}

const DEFAULT_CATEGORIES: [string, CategoryKind, string, string][] = [
  ['Mercado', 'despesa', '🛒', '#16a34a'],
  ['Moradia', 'despesa', '🏠', '#2563eb'],
  ['Contas da casa', 'despesa', '💡', '#ca8a04'],
  ['Transporte', 'despesa', '🚗', '#9333ea'],
  ['Saúde', 'despesa', '🩺', '#dc2626'],
  ['Lazer', 'despesa', '🎉', '#db2777'],
  ['Restaurantes', 'despesa', '🍔', '#ea580c'],
  ['Educação', 'despesa', '📚', '#0891b2'],
  ['Assinaturas', 'despesa', '📺', '#4f46e5'],
  ['Outros', 'despesa', '📦', '#64748b'],
  ['Salário', 'receita', '💼', '#059669'],
  ['Extra', 'receita', '✨', '#0d9488'],
  ['Rendimentos', 'receita', '📈', '#65a30d'],
];

export const db = new FinancasDB();

// ---------------------------------------------------------------------------
// Helpers de escrita — use sempre estes, para manter updatedAt/deletedAt certos.
// ---------------------------------------------------------------------------

type NewRecord<T extends BaseRecord> = Omit<T, keyof BaseRecord>;
type TableName = 'accounts' | 'categories' | 'transactions' | 'budgets';

export async function create<T extends BaseRecord>(table: TableName, data: NewRecord<T>): Promise<string> {
  const now = Date.now();
  const id = crypto.randomUUID();
  await db.table(table).add({ ...data, id, createdAt: now, updatedAt: now });
  return id;
}

export async function update<T extends BaseRecord>(
  table: TableName,
  id: string,
  changes: Partial<NewRecord<T>>,
): Promise<void> {
  await db.table(table).update(id, { ...changes, updatedAt: Date.now() });
}

export async function softDelete(table: TableName, id: string): Promise<void> {
  const now = Date.now();
  await db.table(table).update(id, { deletedAt: now, updatedAt: now });
}

export const alive = <T extends BaseRecord>(r: T) => !r.deletedAt;
