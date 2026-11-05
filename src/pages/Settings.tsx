import { useRef, useState, type FormEvent } from 'react';
import { downloadBackup, importData } from '../backup';
import { create, softDelete, type Category, type CategoryKind } from '../db';
import { useCategories } from '../hooks';

export default function Settings() {
  const categories = useCategories();
  const fileInput = useRef<HTMLInputElement>(null);
  const [message, setMessage] = useState('');
  const [name, setName] = useState('');
  const [icon, setIcon] = useState('🏷️');
  const [kind, setKind] = useState<CategoryKind>('despesa');

  async function onImport(file?: File) {
    if (!file) return;
    try {
      const r = await importData(JSON.parse(await file.text()));
      setMessage(`Importado: ${r.added} novos, ${r.updated} atualizados, ${r.skipped} sem mudança.`);
    } catch (err) {
      setMessage(err instanceof Error ? err.message : 'Falha ao importar.');
    }
    if (fileInput.current) fileInput.current.value = '';
  }

  async function addCategory(e: FormEvent) {
    e.preventDefault();
    if (!name.trim()) return;
    const color = `hsl(${Math.floor(Math.random() * 360)} 65% 45%)`;
    await create<Category>('categories', { name: name.trim(), icon, kind, color });
    setName('');
  }

  return (
    <>
      <header className="page-header"><h1>Ajustes</h1></header>

      <section className="card form">
        <h2>Backup e sincronização</h2>
        <p className="muted">
          Seus dados ficam só neste aparelho. Exporte um backup com frequência. Para levar os dados a outro aparelho,
          exporte aqui e importe lá — a importação mescla, mantendo a versão mais recente de cada lançamento.
        </p>
        <div className="actions">
          <button className="ghost" onClick={() => fileInput.current?.click()}>Importar…</button>
          <button onClick={downloadBackup}>Exportar backup</button>
        </div>
        <input ref={fileInput} type="file" accept="application/json,.json" hidden onChange={(e) => onImport(e.target.files?.[0])} />
        {message && <p>{message}</p>}
      </section>

      <section className="card">
        <h2>Categorias</h2>
        <ul className="list">
          {categories.map((c) => (
            <li key={c.id}>
              <span className="tx-icon">{c.icon}</span>
              <span className="tx-main"><strong>{c.name}</strong><small className="muted">{c.kind}</small></span>
              <div className="tx-actions">
                <button className="ghost" title="Excluir" onClick={() => confirm(`Excluir "${c.name}"?`) && softDelete('categories', c.id)}>🗑️</button>
              </div>
            </li>
          ))}
        </ul>
        <form className="form" onSubmit={addCategory}>
          <div className="row">
            <label className="narrow">Ícone<input value={icon} onChange={(e) => setIcon(e.target.value)} maxLength={4} /></label>
            <label>Nome<input value={name} onChange={(e) => setName(e.target.value)} placeholder="Ex.: Pets" /></label>
            <label>
              Tipo
              <select value={kind} onChange={(e) => setKind(e.target.value as CategoryKind)}>
                <option value="despesa">Despesa</option>
                <option value="receita">Receita</option>
              </select>
            </label>
          </div>
          <div className="actions"><button type="submit">Adicionar categoria</button></div>
        </form>
      </section>
    </>
  );
}
