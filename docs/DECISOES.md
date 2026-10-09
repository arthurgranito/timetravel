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

## Fase 3 — Tela de bloqueio

- **Xcode da CI** → o `macos-latest` atual usa Xcode 26.6 (SDK iOS 26.5). O app continua com deployment target iOS 17 e desenha toda a tela de bloqueio à mão, então o visual não depende do SDK.
- **Entrada na tela preta via UIKit** → `SecretTouchSurface` (UIViewRepresentable) com `UITapGestureRecognizer`, `UILongPressGestureRecognizer` (1 dedo, 0,6s) e `UILongPressGestureRecognizer` (2 dedos, 1,5s) → o SwiftUI não tem gesto de dois dedos nem toque com coordenada + safe areas confiáveis; o UIKit dá as duas coisas. O toque simples espera o toque longo falhar (acontece no instante em que o dedo sobe, sem atraso perceptível).
- **Posições da tela de bloqueio** → cada elemento tem uma posição padrão calculada pelo tipo de aparelho (Dynamic Island / notch / botão Home, detectado pelas safe areas) + um ajuste em pt (`LockScreenStyle`), que a calibração da Fase 4 vai editar → funciona em qualquer iPhone sem coordenadas fixas.
- **Relógio andando** → `TimelineView(.everyMinute)`; a hora usada é `max(data do timeline, Date())` → vira exatamente na borda do minuto e nunca usa uma data atrasada quando a tela é redesenhada por outro motivo.
- **Bateria** → ícone desenhado à mão (contorno clássico ou corpo sólido com a porcentagem), com nível e carregamento reais; verde carregando, amarelo no modo pouca energia, vermelho ≤ 20%. No simulador (nível desconhecido) mostra 100%.
- **Lanterna** → implementada já nesta fase (toque longo de 0,35s liga/desliga a lanterna real; desliga sozinha ao sair da tela de bloqueio ou ir para o background).
- **Efeitos do rewind (padrões)** → haptic por minuto: ligado; haptic de sucesso no fim: ligado; zoom do wallpaper: ligado; cadeado abrindo: ligado; **glitch: desligado** → uma tela de bloqueio real nunca "treme"; deixei como opção para quem quiser mais teatro.
- **Texto "Deslize para cima para abrir"** → opcional, desligado por padrão.
- **Reset no "live"** → toque longo de 1,5s em qualquer lugar da tela (configurável na Fase 4).
- **Transição de acordar** → fade de 0,25s do preto para a tela de bloqueio + wallpaper 1,03 → 1,0 em 0,35s. Voltar para o preto é instantâneo (como apagar a tela).
- **Acessibilidade** → as telas da mágica usam tamanhos fixos, `dynamicTypeSize(.large)` e `legibilityWeight = .regular` → "Texto em negrito" e tamanho de fonte do sistema não alteram nada.
- **Preferências provisórias** → `MagicPreferences` e `LockScreenStyle` usam os valores padrão por enquanto; na Fase 4 passam a vir do `AppSettings`.

## Fase 4 — Configurações e calibração

- **Persistência** → todas as configurações num único JSON (`AppSettingsData`) no UserDefaults, chave `settings.v1` (enum `SettingsKey`). Os padrões ficam nos próprios structs. A decodificação é **tolerante**: campo ausente ou inválido usa o padrão → uma atualização do app que adicione opções nunca apaga suas configurações/calibração. Salva automaticamente a cada mudança.
- **Imagens** → wallpaper e print de calibração salvos como JPEG (qualidade 0,92, maior lado ≤ 3000 px, orientação corrigida) em `Documents/` pelo `WallpaperStore`.
- **Gesto das configurações** → padrão: **3 toques com 2 dedos em até 1,5s** (contados no código, porque o multi-toque nativo do UIKit exige toques muito rápidos). Alternativa: segurar 3s no canto superior esquerdo (100×100 pt abaixo da safe area). Só funciona na tela preta.
- **Calibração** → tela cheia com a tela falsa + o print por cima (opacidade ajustável, botão "segure para ver o print"), e um painel inferior arrastável que deixa a tela visível e tocável. A hora é congelada num valor escolhido (DatePicker), para bater com o print. "Restaurar padrões" volta só os ajustes de calibração (mantém operadora, formatos etc.).
- **Seletor de print** → o PhotosPicker da calibração filtra **capturas de tela**, o do wallpaper filtra imagens.
- **Desenho compartilhado** → `LockScreenCanvas` desenha a tela de bloqueio para um minuto qualquer; a mágica e a calibração usam exatamente o mesmo código → o que você calibra é o que aparece na apresentação.
- **Ensaiar** → sorteia um número dentro da faixa do modo atual, fecha as configurações e mostra a grade com "ENSAIO · faça o N" na tela preta; a grade some quando o rewind termina.
- **Tema das configurações** → também escuro (o app inteiro é forçado no escuro), e sem status bar.

## Fase 5 — Screenshots e polimento

- **Estados de demonstração** → `-demoState …` lido dos argumentos do processo pelo `DemoStateLauncher`, **só em builds Debug** (no Release/.ipa o parser devolve sempre nil) → nenhuma chance de um argumento estranho mudar o app na apresentação.
- **`-demoTime`** → é a hora **real** simulada, congelada (segundos = 5). No estado `lock` a tela mostra `demoTime + demoOffset` (ex.: 14:30 + 8 = 14:38). O `rewinding-mid` mostra o rewind parado na metade (14:34 para N = 8). Padrões: offset 8; hora 14:30 (14:22 no `live`).
- **Hora congelada** → o `TrickController` ganhou `frozenNow` (nil no uso normal) e `clockDate(timelineDate:)`, que a tela de bloqueio usa para decidir a hora real de cada redesenho.
- **Simuladores dos prints** → o iPhone "Pro" de nome mais curto no runtime iOS mais novo; o iPhone SE é procurado e, se não existir, o script tenta criar um. Se nem isso der, o passo do SE é pulado sem falhar o job (aviso no resumo).
- **Ícone** → gerado aqui com Python/Pillow (`scripts/generate_icon.py`) e o PNG 1024×1024 (RGB, sem transparência) já vai commitado; a CI não gera nada → zero chance de a compilação falhar por causa do script do ícone. Formato "single size" do asset catalog (Xcode 14+).
- **Revisão de robustez (seção 8)** → conferido: launch screen preta + raiz preta; status bar escondida no Info.plist e na raiz; `isIdleTimerDisabled` só com o app ativo; volta ao preto ao ir para o background; nenhum texto/botão nas telas da mágica (a grade e o ponto só aparecem com modo treino/ensaio/indicador ligados); tamanhos fixos e `legibilityWeight` regular nas telas da mágica; tema escuro forçado; tudo posicionado por safe areas.
- **Limitação conhecida** → o iOS tira uma "foto" do app ao ir para o background (usada no seletor de apps). O reset para o preto acontece nesse mesmo momento, mas não há garantia de que a foto já saia preta. Na prática: não abra o seletor de apps durante a apresentação.

## Fase 6 — Documentação

- **Arquivos do projeto na raiz do repositório** → o README descreve a estrutura real (sem a pasta `TimeRewind/` do exemplo da especificação).
- **Prints no README** → as folhas de prints (`docs/img/prints-iphone-pro.jpg` e `prints-iphone-se.jpg`) vêm do artifact `screenshots-5` da CI, reduzidas para ficarem leves.
- **Repositório público** → minutos de CI ilimitados; o README explica a diferença para um repositório privado (minutos de macOS contam ~10×, e cada push gasta ~20 min de macOS).
- **Errou o número depois de acender** → o roteiro recomenda bloquear o iPhone (o app volta ao preto sozinho) em vez de criar um gesto de reset extra na tela de bloqueio, que poderia ser disparado sem querer.
