# 📒 Livro-Caixa — finanças da casa

App de finanças pessoal, **offline** e **privado**: os dados ficam num SQLite no próprio aparelho.
Feito em **Flutter**, um código só para **Android, Windows e Linux**, com **release e
atualização automáticos**.

## Começando

```bash
flutter pub get
flutter run -d linux        # ou: -d windows, ou com o celular plugado
flutter test                # regras de dinheiro, saldo, backup e assinatura
dart run build_runner build # depois de mexer nas tabelas (lib/data/database.dart)
```

## Mapa do código

```
lib/
  core/money.dart        dinheiro em centavos: formatar e interpretar "1.234,56"
  core/dates.dart        datas como "AAAA-MM-DD"
  data/database.dart     tabelas (drift/SQLite) + leituras e escritas  ← comece por aqui
  data/app_data.dart     listas em memória que avisam as telas; AppScope
  domain/finance.dart    regras puras: saldo da conta, resumo do mês
  backup/backup.dart     exportar/importar JSON com mesclagem
  updates/               atualização automática (manifesto assinado + instalação)
  ui/pages/              Início, Lançamentos, Contas, Ajustes
  ui/widgets/            formulário de lançamento, banner de atualização, comuns
tool/                    scripts Dart: gerar chaves, montar o latest.json
packaging/               ícone, instalador do Windows (Inno Setup), AppImage
android/.../MainActivity.kt   canal nativo que abre o instalador do APK
```

### Regras importantes já embutidas
- **Dinheiro em centavos (`int`).** Nunca `double`.
- **IDs UUID + `updatedAt` + `deletedAt`** (exclusão lógica). É o que permite juntar os dados de
  dois aparelhos sem bagunça. As categorias padrão têm IDs fixos, então não duplicam na mesclagem.
- **Mudou uma tabela?** Rode o `build_runner`, suba o `schemaVersion` e escreva a migração.

## Release e atualização automática

Igual ao 7Hinos:

1. Commits no padrão **`feat:`**, **`fix:`**, `chore:`… na `main`.
2. O **release-please** abre um PR "chore(main): release x.y.z" com versão e CHANGELOG.
3. **Merge do PR** → tag + release → o CI compila e anexa:
   - `LivroCaixa_x.y.z_android.apk` (assinado)
   - `LivroCaixa_x.y.z_windows-x64-setup.exe` (Inno Setup, instala sem pedir administrador)
   - `LivroCaixa_x.y.z_linux-x86_64.AppImage` e `.tar.gz`
4. O job **Publicar** gera o `latest.json` **assinado (ed25519)** com o SHA-256 de cada instalador.
5. Os apps instalados leem o `latest.json` ao abrir, conferem a assinatura, baixam em segundo
   plano e mostram **Atualizar agora**:
   - **Windows**: roda o instalador em silêncio e reabre o app.
   - **Linux (AppImage)**: troca o arquivo e reabre.
   - **Android**: abre o instalador do sistema (o Android sempre pede um toque).

**Prévias:** um commit com `[instaladores]` numa branch (ou *Actions → Prévia → Run workflow*)
gera uma pré-release para testar. Os apps instalados não se atualizam para prévias.

### Configuração (uma vez só)

**1. Chave das atualizações**
```bash
dart run tool/gen_keys.dart
```
Isso grava a chave pública em `lib/updates/update_key.dart` (faça commit) e mostra a chave privada:
coloque-a no secret **`UPDATE_SIGNING_KEY`**.

Sem Dart instalado, dá para gerar com `openssl` (Linux, macOS ou Git Bash no Windows):
```bash
openssl genpkey -algorithm ed25519 -out livro-caixa-update.pem
openssl pkey -in livro-caixa-update.pem -outform DER | tail -c 32 | base64          # privada -> secret
openssl pkey -in livro-caixa-update.pem -pubout -outform DER | tail -c 32 | base64  # pública -> update_key.dart
```

**2. Keystore do Android**
```bash
keytool -genkeypair -v -keystore livro-caixa-release.jks -alias livrocaixa \
  -keyalg RSA -keysize 4096 -validity 10000
base64 -w0 livro-caixa-release.jks   # conteúdo do secret ANDROID_KEYSTORE_BASE64
```

| Secret (Settings → Secrets and variables → Actions) | Para quê |
|---|---|
| `UPDATE_SIGNING_KEY` | Assina o `latest.json` |
| `ANDROID_KEYSTORE_BASE64` | Keystore do Android, em base64 |
| `ANDROID_KEYSTORE_PASSWORD` | Senha do keystore (e da chave) |

> ⚠️ **Guarde a keystore e a chave privada fora do Git e com backup.** Se perder a keystore, o
> Android não aceita mais instalar por cima e todo mundo precisa desinstalar (perdendo os dados
> locais, se não tiver backup). Se perder a chave de atualização, os apps param de se atualizar sozinhos.

**3. Repositório público.** O app baixa as releases sem token, então o repositório precisa ser
público. Só o código fica visível; os dados financeiros nunca saem dos aparelhos.

## Compartilhar com a esposa (hoje)
Ajustes → **Exportar backup** num aparelho → mande o arquivo → **Importar** no outro.
A importação junta tudo: vence a edição mais recente, e as exclusões também passam.

## Ideias para evoluir

**Fáceis**
- [ ] Editar contas e categorias (hoje só cria, arquiva e exclui)
- [ ] Filtro por categoria ou conta nos lançamentos
- [ ] Orçamento mensal por categoria (a tabela `budgets` já existe!)
- [ ] Destaque para contas a vencer nos próximos dias
- [ ] Campo "quem lançou" (você ou sua esposa)

**Médias**
- [ ] Lançamentos recorrentes (aluguel, assinaturas) e parcelados (3/10)
- [ ] Cartão de crédito com fatura (fechamento e vencimento)
- [ ] Gráfico de evolução mês a mês (`fl_chart`)
- [ ] Importar extrato OFX/CSV do banco
- [ ] Metas e caixinhas (viagem, reserva de emergência)
- [ ] Bloqueio com PIN ou biometria (`local_auth`)

**Sincronização automática** (sem perder o offline)
- Backup automático numa pasta sincronizada (Syncthing, Drive para desktop)
- Mini-servidor em casa (Dart `shelf` + SQLite) com um `/sync` que usa o `updatedAt` que já existe
- Google Drive (como no Sépia)

**Mais plataformas:** `flutter create --platforms=macos .` e mais um job no `build.yml`.
