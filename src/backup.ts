import { db, type BaseRecord, type FinancasDB } from './db';

// Backup em arquivo JSON. Também serve como "sincronização manual":
// você exporta no celular, importa no computador (ou no celular da esposa),
// e a importação MESCLA os dados: para cada registro, fica a versão com
// `updatedAt` mais recente. Exclusões viajam junto (via `deletedAt`).

const TABLES = ['accounts', 'categories', 'transactions', 'budgets'] as const;
const FORMAT = 'tostao-backup';
const VERSION = 1;

export interface BackupFile {
  format: typeof FORMAT;
  version: number;
  exportedAt: string;
  data: Record<(typeof TABLES)[number], BaseRecord[]>;
}

export async function exportData(database: FinancasDB = db): Promise<BackupFile> {
  const data = {} as BackupFile['data'];
  for (const t of TABLES) data[t] = await database.table(t).toArray();
  return { format: FORMAT, version: VERSION, exportedAt: new Date().toISOString(), data };
}

export interface MergeResult {
  added: number;
  updated: number;
  skipped: number;
}

export async function importData(file: unknown, database: FinancasDB = db): Promise<MergeResult> {
  const backup = file as BackupFile;
  if (backup?.format !== FORMAT || typeof backup.data !== 'object') {
    throw new Error('Arquivo não é um backup válido do Tostão.');
  }
  if (backup.version > VERSION) {
    throw new Error('Backup feito numa versão mais nova do app. Atualize o app primeiro.');
  }

  const result: MergeResult = { added: 0, updated: 0, skipped: 0 };
  await database.transaction('rw', TABLES.map((t) => database.table(t)), async () => {
    for (const t of TABLES) {
      const incoming = backup.data[t] ?? [];
      const table = database.table<BaseRecord, string>(t);
      const existing = await table.bulkGet(incoming.map((r) => r.id));
      const toPut: BaseRecord[] = [];
      incoming.forEach((rec, i) => {
        const local = existing[i];
        if (!local) {
          result.added++;
          toPut.push(rec);
        } else if (rec.updatedAt > local.updatedAt) {
          result.updated++;
          toPut.push(rec);
        } else {
          result.skipped++;
        }
      });
      await table.bulkPut(toPut);
    }
  });
  return result;
}

/** Faz o navegador baixar o backup como arquivo .json */
export async function downloadBackup(): Promise<void> {
  const backup = await exportData();
  const blob = new Blob([JSON.stringify(backup, null, 2)], { type: 'application/json' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = `tostao-backup-${backup.exportedAt.slice(0, 10)}.json`;
  a.click();
  URL.revokeObjectURL(url);
}
