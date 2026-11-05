import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { registerSW } from 'virtual:pwa-register';
import App from './App';
import './styles.css';

// Registra o service worker: é ele que deixa o app abrir sem internet.
registerSW({ immediate: true });

// Pede ao navegador para não apagar os dados quando o espaço estiver baixo.
navigator.storage?.persist?.();

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <App />
  </StrictMode>,
);
