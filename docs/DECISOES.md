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

## Fase 2 — Núcleo

- **Buffer da entrada secreta** → o estado `dark` não carrega o buffer; ele vive no `SecretInput` do `TrickController` (fase `empty/counting/tens/armed`) → a `TrickState` fica simples e o `SecretInput` continua uma struct pura e testável.
- **Margem da grade** → toques nos 40pt de margem (topo/base) são **ignorados** (não mudam nada) → evita número errado por toque perto dos gestos do sistema.
- **Modo B acima de 30 toques** → o toque longo de confirmação dá **erro + reset** (não corta em 30) → cortar silenciosamente daria um número errado sem você perceber.
- **Modo B, toque longo sem toques** → erro + reset.
- **Modo C, linha do zero** → a área útil vira 4 linhas: 3 da grade 1–9 e uma linha extra embaixo, onde só a célula do meio vale "0"; laterais dessa linha são ignoradas. Dezena 6–9 = erro imediato.
- **Timeout de inatividade** → vale para entradas parciais dos modos B **e** C (dezena esperando unidade) → uma dezena "esquecida" seria tão perigosa quanto uma contagem velha. Número já armado não expira.
- **Alvo dinâmico do rewind** → a cada passo o minuto mostrado desce 1, mas nunca abaixo da hora real *naquele instante*; quando encosta na hora real, termina. Se o minuto virar durante a animação, ela termina um passo antes, sempre exatamente na hora real e sem repetir valores. Se os passos acabarem (ex.: relógio do sistema andou para trás), encaixa na hora real.
- **Curva do rewind** → peso de cada intervalo = `1 − 0,65·sin(π·p)` (pontas lentas, meio rápido), normalizado para somar a duração. Duração mínima de 1,2s vale para qualquer N.
- **Voltar ao preto** → acontece quando o app **vai** para o background (não quando volta) → ao reabrir, o preto já está lá, sem nenhum frame da tela de bloqueio antiga. Não vale nas configurações, para não perder o que você está editando.
- **Feedback (haptics)** → o controller só emite eventos (`TrickFeedback`); quem toca o haptic é a camada de serviços (Fase 3) → lógica testável, sem UIKit no núcleo.
- **Configuração do núcleo** → `TrickConfiguration` (struct) aplicada via `updateConfiguration(_:)`; na Fase 4 ela passa a ser montada a partir do `AppSettings`.
- **Verificação local** → `scripts/verify-core-linux.sh` compila `Core/` e roda `Tests/` com um toolchain Swift no Linux (com stubs de `os`/`CoreGraphics`) → pega erros de lógica/compilação antes de gastar um ciclo de CI. Não substitui a CI (sem SwiftUI/UIKit).
- **Testes do controller** → métodos `async` numa classe `@MainActor` → funcionam tanto no Xcode quanto na descoberta de testes do Linux.
- **Simulador da CI** → `scripts/pick_simulator.py` pega o runtime iOS mais novo e prefere "iPhone 15", senão o primeiro iPhone → não quebra quando a imagem do runner muda.
