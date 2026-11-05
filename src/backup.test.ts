import 'fake-indexeddb/auto';
import { describe, expect, it } from 'vitest';
import { FinancasDB } from './db';
import { exportData, importData } from './backup';

describe('backup', () => {
  it('mescla mantendo a versão mais recente de cada registro', async () => {
    const celular = new FinancasDB('celular');
    const pc = new FinancasDB('pc');
    await celular.open();
    await pc.open();

    // Copia tudo do celular para o PC (como se fosse a primeira sincronização)
    const first = await importData(await exportData(celular), pc);
    expect(first.added).toBeGreaterThan(0);

    // Edita no celular depois; no PC, uma edição mais antiga
    const [acc] = await celular.accounts.toArray();
    await pc.accounts.update(acc.id, { name: 'PC (velho)', updatedAt: acc.updatedAt + 1 });
    await celular.accounts.update(acc.id, { name: 'Celular (novo)', updatedAt: acc.updatedAt + 2 });

    const second = await importData(await exportData(celular), pc);
    expect(second.updated).toBe(1);
    expect((await pc.accounts.get(acc.id))?.name).toBe('Celular (novo)');
  });

  it('recusa arquivos que não são backup', async () => {
    await expect(importData({ foo: 1 }, new FinancasDB('x'))).rejects.toThrow();
  });
});
