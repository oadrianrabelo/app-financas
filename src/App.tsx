import { useEffect, useState } from 'react';
import Dashboard from './pages/Dashboard';
import Transactions from './pages/Transactions';
import Accounts from './pages/Accounts';
import Settings from './pages/Settings';

// Navegação simples por "#hash" na URL — sem biblioteca de rotas.
const PAGES = {
  inicio: { label: 'Início', icon: '🏠', Component: Dashboard },
  lancamentos: { label: 'Lançamentos', icon: '📋', Component: Transactions },
  contas: { label: 'Contas', icon: '🏦', Component: Accounts },
  ajustes: { label: 'Ajustes', icon: '⚙️', Component: Settings },
} as const;
type PageKey = keyof typeof PAGES;

function currentPage(): PageKey {
  const hash = location.hash.slice(1);
  return hash in PAGES ? (hash as PageKey) : 'inicio';
}

export default function App() {
  const [page, setPage] = useState<PageKey>(currentPage);

  useEffect(() => {
    const onHash = () => setPage(currentPage());
    window.addEventListener('hashchange', onHash);
    return () => window.removeEventListener('hashchange', onHash);
  }, []);

  const { Component } = PAGES[page];

  return (
    <div className="app">
      <nav className="nav">
        <div className="brand">🪙 Tostão</div>
        {(Object.keys(PAGES) as PageKey[]).map((key) => (
          <a key={key} href={`#${key}`} className={key === page ? 'active' : ''}>
            <span className="nav-icon">{PAGES[key].icon}</span>
            <span>{PAGES[key].label}</span>
          </a>
        ))}
      </nav>
      <main className="content">
        <Component />
      </main>
    </div>
  );
}
