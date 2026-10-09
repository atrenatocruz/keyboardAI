# KeyboardAI

Teclado iOS em português de Portugal com um botão ✨ que melhora o texto com IA (Claude Haiku 5.5).

- Design: `docs/superpowers/specs/2026-10-09-keyboard-ai-design.md`
- Plano: `docs/superpowers/plans/2026-10-09-keyboard-ai-mvp.md`
- Checklist manual: `docs/testing/manual-checklist.md`

## Backend (Cloudflare Workers + D1)

```bash
cd backend
npm install
npm test
npx wrangler login
npx wrangler d1 create keyboardai          # copia o database_id para wrangler.toml
npx wrangler d1 migrations apply keyboardai --remote
npx wrangler secret put ANTHROPIC_API_KEY
npx wrangler deploy                        # anota o URL https://keyboardai.<sub>.workers.dev
```

Desenvolvimento local: `cp .dev.vars.example .dev.vars` (põe a tua chave), `npx wrangler d1 migrations apply keyboardai --local`, `npm run dev`. O `wrangler dev` corre em http://localhost:8787; para o simulador iOS podes definir `API_BASE_URL = http:/$()/localhost:8787` em `ios/Config/Secrets.xcconfig` (o `$()` evita que o `//` seja lido como comentário).

Eval de qualidade PT-PT (gasta créditos): `ANTHROPIC_API_KEY=... npm run eval` → `backend/eval/report.md`.

## iOS (Mac com Xcode 15+)

```bash
brew install xcodegen
cd ios
cp Config/Secrets.xcconfig.example Config/Secrets.xcconfig   # põe o URL do Worker e o teu Team ID
xcodegen generate
open KeyboardAI.xcodeproj
```

Testes do core: `cd ios/Packages/KeyboardCore && swift test`.

Instalar no iPhone (conta Apple gratuita):
1. Xcode → Settings → Accounts → adiciona o teu Apple ID (Personal Team).
2. Liga o iPhone, ativa o Modo de Programador (Definições → Privacidade e segurança).
3. Escolhe o iPhone como destino e carrega em Run (esquema `KeyboardAI`).
4. No iPhone: Definições → Geral → VPN e gestão de dispositivos → confia no teu certificado.
5. Definições → Geral → Teclado → Teclados → Adicionar → KeyboardAI → ativa "Permitir acesso total".

A instalação com conta gratuita expira ao fim de 7 dias. Para renovar, volta a carregar em Run.

## Estado

Ainda por verificar (o código iOS foi escrito em Windows, sem toolchain Swift):

- `swift test` em `ios/Packages/KeyboardCore` e as verificações de build/simulador no Xcode nunca foram executados; corre-os primeiro no Mac.
- Depois de `xcodegen generate`, os dois `Info.plist` (`ios/App/Info.plist` e `ios/KeyboardExtension/Info.plist`) aparecem como modificados, porque o XcodeGen os regenera.
