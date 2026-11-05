import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { VitePWA } from 'vite-plugin-pwa';

// O plugin PWA gera o service worker (cache offline) e o manifest
// (que permite "instalar" o app no celular e no computador).
export default defineConfig({
  plugins: [
    react(),
    VitePWA({
      registerType: 'autoUpdate',
      includeAssets: ['icon.svg'],
      manifest: {
        name: 'Tostão — Finanças da Casa',
        short_name: 'Tostão',
        description: 'Controle financeiro pessoal, offline e privado.',
        lang: 'pt-BR',
        theme_color: '#0f766e',
        background_color: '#0b1514',
        display: 'standalone',
        start_url: '/',
        icons: [
          { src: 'icon.svg', sizes: 'any', type: 'image/svg+xml', purpose: 'any maskable' },
        ],
      },
      workbox: {
        globPatterns: ['**/*.{js,css,html,svg,png,woff2}'],
      },
    }),
  ],
});
