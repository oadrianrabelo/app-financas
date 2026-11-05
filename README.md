# 🪙 Tostão — finanças da casa

App de finanças pessoal, **offline**, **privado** (os dados ficam só no seu aparelho) e que roda no
**computador e no celular** com o mesmo código. É um PWA: abre no navegador e pode ser "instalado"
como app.

## Começando

```bash
npm install
npm run dev        # abre em http://localhost:5173 (e no IP da rede, p/ testar no celular)
npm test           # testes das regras de dinheiro, saldo e backup
npm run build      # gera a versão final em dist/
npm run preview    # serve o build (é aqui que o modo offline funciona de verdade)
```

> O service worker (offline) só funciona no `build`/`preview` ou em produção, não no `dev`.

## Stack (e por quê)

| Peça | Escolha | Por quê |
|---|---|---|
| Linguagem | **TypeScript** | Tipos pegam erro de dinheiro/campo antes de rodar. |
| Interface | **React** | Maior comunidade, muito material em português. |
| Build | **Vite** | Rápido, zero configuração chata. |
| Banco local | **IndexedDB via Dexie** | Banco de verdade dentro do navegador, funciona offline. |
| Offline/instalável | **vite-plugin-pwa** | Gera service worker + manifest sozinho. |
| Testes | **Vitest** | Mesmo config do Vite. |

Sem biblioteca de rotas, de estado ou de CSS: dá para entender tudo lendo o código.

## Mapa do código

```
src/
  db.ts          modelo de dados + banco (comece por aqui)
  money.ts       dinheiro em centavos: formatar e interpretar "1.234,56"
  dates.ts       datas como "AAAA-MM-DD"
  finance.ts     regras puras: saldo de conta, resumo do mês
  backup.ts      exportar/importar JSON com mesclagem
  hooks.ts       consultas "ao vivo" ao banco para as telas
  App.tsx        navegação (#inicio, #lancamentos, #contas, #ajustes)
  pages/         uma tela por arquivo
  components/    formulário de lançamento, seletor de mês
  styles.css     tema claro/escuro, layout celular x computador
```

### Regras importantes já embutidas
- **Dinheiro em centavos inteiros.** Nunca `float`.
- **IDs UUID + `updatedAt` + `deletedAt`** (exclusão "lógica"). Isso é o que permite
  mesclar dados de dois aparelhos sem bagunça — é a base da sincronização.
- **Mudou o esquema do banco?** Crie `this.version(2)` em `db.ts`; nunca edite a versão 1.

## Usar no celular e compartilhar com a esposa

1. **Publicar o app** (é só HTML/JS, os dados NÃO vão para o servidor): `npm run build` e suba a
   pasta `dist/` no Cloudflare Pages, Netlify ou Vercel (grátis). Celular exige HTTPS para o modo
   offline, e esses serviços já dão isso.
   - GitHub Pages também serve, mas aí configure `base: '/app-financas/'` no `vite.config.ts`.
2. No celular, abra o link → menu do navegador → **"Adicionar à tela inicial"**.
3. **Sincronizar (hoje):** Ajustes → *Exportar backup* num aparelho → mande o arquivo
   (WhatsApp, Drive…) → *Importar* no outro. A importação mescla: vence a edição mais recente.

## Ideias para evoluir (sugestão de ordem)

**Fáceis**
- [ ] Editar contas e categorias (hoje só cria/exclui)
- [ ] Filtro por categoria/conta na lista de lançamentos
- [ ] Orçamento mensal por categoria (a tabela `budgets` já existe!) com barra de progresso
- [ ] Lembrete visual de contas vencendo (lançamentos não pagos com data próxima)
- [ ] Campo "quem lançou" (você / esposa)

**Médias**
- [ ] Lançamentos recorrentes (aluguel, assinaturas) e parcelados (`3/10`)
- [ ] Cartão de crédito com fatura: data de fechamento/vencimento
- [ ] Gráfico de evolução mês a mês (ex.: biblioteca `chart.js` ou SVG na mão)
- [ ] Importar extrato **OFX/CSV** do banco
- [ ] Metas/caixinhas ("Viagem", "Reserva de emergência")
- [ ] Bloqueio com PIN

**Sincronização automática (quando cansar do arquivo)** — sem abrir mão do offline:
- **Pasta sincronizada:** salvar o backup numa pasta do Syncthing/Drive (File System Access API no PC).
- **PouchDB + CouchDB** na sua casa (Raspberry Pi / PC sempre ligado): sync automático, offline-first.
- **Dexie Cloud:** sync pronto para o Dexie (tem plano grátis pequeno, mas os dados passam pelo serviço).
- **Seu próprio mini-servidor** (Node/Go + SQLite) com endpoint `/sync` usando o `updatedAt` que já existe.

**Outras plataformas no futuro:** embrulhar este mesmo código com **Capacitor** (app Android/iOS) ou
**Tauri** (app de desktop) — sem reescrever nada.
