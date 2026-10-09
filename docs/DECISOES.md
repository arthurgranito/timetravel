# Registro de decisões

Formato: **contexto → decisão → motivo**.

## Fase 1 — Fundação

- **Raiz do repositório** → os arquivos do projeto ficam direto na raiz do repo (não numa subpasta `TimeRewind/`) → a CI e o `project.yml` ficam mais simples, sem `working-directory`.
- **`SWIFT_VERSION`** → `5.0` (com `SWIFT_STRICT_CONCURRENCY = minimal`) → o Xcode só aceita valores de "modo de linguagem" (`4`, `4.2`, `5.0`, `6.0`); `5.10` é rejeitado. O modo 5 com o compilador atual equivale ao Swift 5.10 pedido e evita os erros de concorrência do Swift 6.
- **Info.plist** → gerado pelo XcodeGen em `Supporting/Info.plist` (fora das pastas de `sources`) e ignorado no git → fonte única da verdade é o `project.yml`; ficar fora de `sources` evita que ele seja copiado como recurso.
- **Nome na tela inicial** → variável `APP_DISPLAY_NAME` no `project.yml` (padrão "Notas Rápidas") → fácil de trocar num lugar só.
- **Ícone** → `ASSETCATALOG_COMPILER_APPICON_NAME` vazio até a Fase 5 → garante que o build nunca falhe por causa do ícone.
- **Tema** → `UIUserInterfaceStyle = Dark` no Info.plist, além de `.preferredColorScheme(.dark)` → o sistema nunca desenha nada claro, nem durante o launch.
- **Gatilho da CI** → `push` em **qualquer branch** (`"**"`) + `workflow_dispatch` → o desenvolvimento acontece em branches de trabalho, não só na `main`. `concurrency` cancela builds antigos da mesma branch para economizar minutos de macOS.
- **Gesto da borda inferior** → `.defersSystemGestures(on: .bottom)` já na tela preta → o primeiro swipe acidental de baixo não tira o app da tela.
