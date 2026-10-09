# PROMPT — App de mágica "Voltar no Tempo" (iOS / SwiftUI)

Você vai construir do zero um app iOS nativo em SwiftUI para uma mágica de close-up. Leia este documento inteiro antes de escrever qualquer código. Ele é a especificação completa. Onde algo não estiver especificado, **decida você mesmo** pela opção mais simples e robusta, registre a decisão em `docs/DECISOES.md` e siga em frente. Não me faça perguntas a menos que esteja realmente bloqueado.

---

## 0. Contexto e restrições críticas (leia com atenção)

- **Eu NÃO tenho Mac.** Estou no Windows. Não posso rodar Xcode, simulador, nem compilar localmente.
- O app será **compilado no GitHub Actions** (runner macOS), gerando um `.ipa` **sem assinatura**, que eu instalo no meu iPhone com **Sideloadly + Apple ID grátis**.
- Consequência: **cada erro de compilação me custa um ciclo inteiro** (push → esperar a CI → copiar o log → te mandar). Por isso:
  - Escreva código que compile **de primeira**. Prefira APIs estáveis e conhecidas a APIs novas ou exóticas.
  - **Zero dependências externas** (sem Swift Package Manager, sem CocoaPods).
  - Nenhuma capability ou entitlement que exija conta paga (sem App Groups, push, iCloud, widgets, Live Activities etc.).
  - Deployment target: **iOS 17.0**. Pode usar `@Observable`, `.contentTransition(.numericText())`, `PhotosPicker`, `.sensoryFeedback` etc.
  - Configure `SWIFT_VERSION = 5.10` (ou 5.x equivalente disponível) e **não** ative strict concurrency completa, pra evitar erros de concorrência do Swift 6 que eu não consigo depurar.
  - Marque tipos de UI/estado com `@MainActor` quando fizer sentido, e evite `Task.detached` e concorrência desnecessária.
  - Antes de terminar cada fase, **revise o código como se fosse o compilador**: imports, tipos, nomes, parâmetros de inicializadores, chaves de `@AppStorage`, nomes de arquivos referenciados no `project.yml`.
- Escreva código **completo**. Nunca use placeholders tipo `// TODO`, `// implementar aqui` ou trechos resumidos com `...`.
- Idioma: código e identificadores em inglês; textos da UI de configurações, comentários importantes, README e docs em **português do Brasil**.

---

## 1. O efeito (do ponto de vista da plateia)

1. O mágico mostra o celular dele **com a tela apagada**.
2. Pede pra alguém falar um número de 1 a 9: "se você pudesse voltar no tempo, quantos minutos voltaria?". A pessoa fala, por exemplo, **8**.
3. O mágico pega o celular, "acende" a tela, e aparece a **tela de bloqueio normal do iPhone**, com a hora.
4. Ele faz o gesto de desbloquear e o **relógio começa a voltar, minuto por minuto**, até ter voltado 8 minutos.
5. A plateia confere **os próprios celulares**, e a hora deles bate exatamente com a hora "nova". Parece que o mundo inteiro voltou 8 minutos.

### O segredo (o que o app realmente faz)

- A "tela apagada" é o app mostrando **preto puro** (#000000), que numa tela OLED é indistinguível de tela desligada.
- Enquanto a tela está "apagada", o mágico **insere o número secretamente** com um toque numa posição específica da tela (ver seção 4).
- A tela de bloqueio é **falsa**: um clone feito no app. Ela mostra **hora real + N minutos**.
- O "voltar no tempo" é uma animação que leva o relógio falso de `real + N` até `real`. Ao final, o relógio falso está **sincronizado com a hora real** e continua andando normalmente. Por isso bate com o celular de todo mundo.

O app inteiro existe para que isso seja **impossível de perceber**. Fidelidade visual e confiabilidade são as prioridades número 1 e 2.

---

## 2. Arquitetura geral

### 2.1 Estrutura do projeto

Use **XcodeGen** (`project.yml`) para gerar o `.xcodeproj` na CI. **Não** commite o `.xcodeproj`. Coloque `*.xcodeproj` no `.gitignore`.

Estrutura sugerida (ajuste se necessário, mas mantenha a separação de responsabilidades):

```
TimeRewind/
├── project.yml
├── .gitignore
├── README.md
├── docs/
│   ├── DECISOES.md
│   └── COMO_APRESENTAR.md
├── .github/workflows/
│   └── build.yml
├── scripts/
│   └── (scripts auxiliares da CI, se precisar)
├── App/
│   ├── TimeRewindApp.swift
│   └── RootView.swift
├── Core/
│   ├── TrickState.swift          // máquina de estados
│   ├── TrickController.swift     // @Observable, orquestra tudo
│   ├── TimeEngine.swift          // lógica pura de tempo (testável)
│   ├── SecretInput.swift         // lógica pura da entrada secreta (testável)
│   └── RewindPlanner.swift       // calcula a sequência/timing da animação (testável)
├── Settings/
│   ├── AppSettings.swift         // todas as configurações (@AppStorage / UserDefaults)
│   └── WallpaperStore.swift      // salva/carrega imagens no Documents
├── Services/
│   ├── Haptics.swift
│   ├── BatteryMonitor.swift
│   └── ScreenBrightness.swift
├── Views/
│   ├── DarkScreenView.swift
│   ├── LockScreen/
│   │   ├── LockScreenView.swift
│   │   ├── LockClockView.swift
│   │   ├── LockDateView.swift
│   │   ├── FakeStatusBar.swift
│   │   ├── PadlockView.swift
│   │   ├── QuickActionButton.swift   // lanterna e câmera
│   │   └── UnlockHintView.swift
│   ├── Settings/
│   │   ├── SettingsView.swift
│   │   └── CalibrationView.swift
│   └── Debug/
│       └── DemoStateLauncher.swift   // estados forçados via launch arguments (para screenshots da CI)
├── Resources/
│   └── Assets.xcassets/ (AppIcon, cores)
└── Tests/
    ├── TimeEngineTests.swift
    ├── SecretInputTests.swift
    └── RewindPlannerTests.swift
```

### 2.2 Configuração do `project.yml`

- Target app iOS `TimeRewind`, plataforma iOS, deployment target 17.0, apenas iPhone (`TARGETED_DEVICE_FAMILY = 1`).
- Target de testes unitários `TimeRewindTests` (bundle de testes que roda no simulador).
- Info.plist gerado pelo XcodeGen com:
  - `CFBundleDisplayName`: nome discreto e configurável no `project.yml` (padrão: **"Notas Rápidas"**, pra não chamar atenção na tela inicial).
  - `UIStatusBarHidden = true` e `UIViewControllerBasedStatusBarAppearance = false` (status bar escondida desde o launch).
  - `UISupportedInterfaceOrientations`: apenas `UIInterfaceOrientationPortrait`.
  - `UIRequiresFullScreen = true`.
  - `UILaunchScreen` com **fundo preto** (cor de asset `LaunchBlack` = #000000). **Não pode haver flash branco ao abrir o app.**
  - `NSPhotoLibraryUsageDescription` (se o PhotosPicker exigir; o PhotosPicker normalmente não exige, mas inclua por segurança).
  - `UIApplicationSceneManifest` padrão do SwiftUI.
- Bundle ID: `com.magic.timerewind` (o Sideloadly pode trocar, tudo bem).
- `CODE_SIGNING_ALLOWED = NO` só na CI via linha de comando; não force no projeto.
- Asset catalog com `AppIcon` (ver seção 9.4) e as cores necessárias.

### 2.3 Máquina de estados (`TrickState`)

```
idle/dark(input: SecretInputBuffer)   // tela preta, aguardando entrada secreta
   └─ número confirmado ──▶ armed(offset: N)         // ainda preto, número guardado
armed(offset)
   └─ gesto de "acordar" ──▶ lockScreen(offset: N)   // tela de bloqueio mostrando real + N
lockScreen(offset)
   └─ gatilho de rewind ──▶ rewinding(from: N)       // animação voltando
rewinding
   └─ terminou ──▶ live                              // tela de bloqueio sincronizada com a hora real
live
   └─ long press (configurável) ──▶ dark             // reset para nova apresentação
qualquer estado
   └─ app volta do background ──▶ dark (configurável, padrão: ligado)
   └─ gesto secreto de configurações (só no dark) ──▶ settings
```

Requisitos:
- Transições **determinísticas** e centralizadas no `TrickController`. Nenhuma view altera estado por conta própria.
- `offset` em minutos (Int). Faixa válida depende do modo de entrada (seção 4).
- Logs de debug via `os.Logger` (subsystem do bundle), sem prints espalhados.

---

## 3. Lógica de tempo (`TimeEngine`) — tem que ser à prova de bala

Funções **puras** e testáveis, recebendo `now: Date` e `calendar: Calendar` por parâmetro (nunca chamando `Date()` lá dentro), para os testes serem determinísticos.

- `displayedDate(now:offsetMinutes:) -> Date`: retorna `now + offset * 60`.
- A exibição é sempre **truncada ao minuto** (segundos ignorados), igual ao relógio do iPhone.
- **O relógio falso precisa continuar andando** durante toda a apresentação. Se o mágico demorar 2 minutos entre acender a tela e fazer o rewind, a hora mostrada (`real + N`) também avança 2 minutos. Nunca congele a hora.
- O "tick" do minuto tem que acontecer **exatamente** quando o minuto real vira (não 1 segundo depois). Use `TimelineView(.everyMinute)` ou um timer alinhado à próxima borda de minuto. Se usar `Timer`, recalcule a cada disparo a partir de `Date()`, sem acumular deriva.
- Viradas que **precisam** funcionar e ter teste unitário:
  - Virada de hora: 14:03 com N=8 → mostra 14:11 → volta até 14:03 (e o inverso: real 14:58, N=5, mostra 15:03, volta até 14:58).
  - Virada de dia: real 23:57, N=6 → mostra 00:03 do dia seguinte e **a data também muda** na tela; ao voltar, a data volta para o dia certo.
  - Virada de mês e de ano (31/12 23:59).
  - Horário de verão: use sempre `Calendar`/`Date` corretamente; teste com um fuso que tenha DST (ex.: `America/New_York`), mesmo que o Brasil não use mais.
- Formatação:
  - Hora no formato configurável: 24h (padrão) ou 12h; **zero à esquerda na hora** configurável (padrão: ligado, ex. "09:41"). Separador ":".
  - Data no formato da tela de bloqueio do iOS em pt-BR. Padrão: `"EEEE, d 'de' MMMM"` com `Locale(identifier: "pt_BR")` → "quinta-feira, 8 de outubro". Deixe o formato **editável nas configurações** (string de formato) e uma opção para capitalizar a primeira letra.
  - Formatters criados uma vez só (cache), não a cada render.

---

## 4. Entrada secreta do número (`SecretInput`) — o coração do método

Toda entrada acontece na **tela preta** (estado `dark`). Precisa parecer que o mágico só está tocando na tela pra "acordar" o celular.

### 4.1 Modo A — Grade 3x3 (padrão, números 1 a 9)

- A tela é dividida invisivelmente numa grade 3x3, com a numeração de um teclado de telefone:
  ```
  1 2 3
  4 5 6
  7 8 9
  ```
- **Um toque** em uma célula define N e passa para `armed(N)`.
- O **segundo toque, em qualquer lugar**, acende a tela de bloqueio (`lockScreen(N)`).
- A área útil da grade respeita as safe areas e ignora uma margem de 40pt no topo e embaixo (pra não conflitar com gestos do sistema).

### 4.2 Modo B — Contagem de toques (1 a 30)

- Cada toque rápido na tela preta soma 1 (com haptic sutil opcional por toque).
- Um **toque longo** (0,6s) confirma e já acende a tela de bloqueio com N = número de toques.
- Timeout de inatividade de 5s zera a contagem (configurável).

### 4.3 Modo C — Grade em duas etapas (1 a 59)

- Primeiro toque na grade = dezena (posição 1 a 5; o "0" é um toque no centro inferior, abaixo da grade); segundo toque = unidade (grade 1–9, e "0" no centro inferior).
- Terceiro toque em qualquer lugar acende a tela.
- Valida: resultado precisa ficar entre 1 e 59; se der 0 ou inválido, haptic de erro e reset.

### 4.4 Comuns a todos os modos

- **Feedback secreto** configurável:
  - Haptic: nenhum / leve (padrão) / padrão por dígito (N batidas leves, pra confirmar o número só pelo tato).
  - Indicador visual: desligado (padrão) / um ponto cinza-escuro de 3pt num canto, visível por 0,5s, só pra quem sabe onde olhar.
- **Reset**: toque longo de 1,5s com **dois dedos** na tela preta zera tudo e volta para `dark` limpo.
- **Modo treino** (nas configurações): mostra a grade desenhada por cima da tela preta com os números, pra eu treinar a posição dos toques.
- `SecretInput` é uma struct pura (recebe eventos `tap(at:in:)`, `longPress`, `timeout` e devolve o novo estado e possíveis ações). Escreva testes unitários para mapeamento de coordenadas → número em várias resoluções de iPhone (SE, 13 mini, 15, 15 Pro Max) e para os três modos.

---

## 5. Tela de bloqueio falsa — tem que ser indistinguível da real

Referência: tela de bloqueio do **iOS 17/18 em português do Brasil**, num iPhone com Face ID (Dynamic Island ou notch). O hardware (Dynamic Island/notch) é real e continua lá; o app desenha todo o resto.

### 5.1 Camadas (de baixo pra cima)

1. **Wallpaper**: imagem escolhida pelo usuário (PhotosPicker), em `scaledToFill`, ocupando a tela toda incluindo as safe areas. Padrão sem imagem: um gradiente escuro neutro.
   - Opção de leve escurecimento (overlay preto 0–30%, padrão 0%).
2. **Status bar falsa** (`FakeStatusBar`), porque a status bar do sistema fica escondida:
   - Esquerda: nome da operadora (texto configurável, padrão "TIM"). Em iPhones com Dynamic Island, a tela de bloqueio real mostra a operadora à esquerda.
   - Direita: barras de sinal, ícone de Wi-Fi e bateria.
   - Bateria: usar o **nível real** (`UIDevice.current.isBatteryMonitoringEnabled = true`) e o estado de carregamento real (raio quando carregando). Desenhe o ícone com SF Symbols (`battery.100`, `battery.75`, `battery.50`, `battery.25`, `battery.0`, `battery.100.bolt`) ou desenhe à mão com shapes para ficar mais fiel. A opção de mostrar a porcentagem dentro do ícone é configurável (o iOS 17+ tem essa opção).
   - Sinal: SF Symbol `cellularbars` com nível configurável (padrão 4/4 cheio). Wi-Fi: `wifi`, liga/desliga nas configurações.
   - Fonte: SF Pro, semibold, ~15–17pt, branca. **Posição vertical alinhada com a Dynamic Island/notch** (ajustável na calibração).
3. **Cadeado** (`PadlockView`) no topo central, abaixo da Dynamic Island: SF Symbol `lock.fill`, pequeno, branco. Ao disparar o rewind, anima pra `lock.open.fill` com um leve bounce (imitando o desbloqueio por Face ID). Ligável/desligável.
4. **Data** (`LockDateView`): acima do relógio, SF Pro semibold ~20pt, branca com leve transparência (configurável).
5. **Relógio** (`LockClockView`): o elemento principal.
   - Dígitos grandes (~96–110pt), fonte do sistema com **design, peso, tamanho, espaçamento entre letras e posição Y configuráveis**, porque o relógio do iOS é customizável e cada pessoa tem o seu. Padrões: `.system(size: 104, weight: .semibold, design: .rounded)`, cor branca.
   - Opção de cor do relógio (branco padrão; color picker nas configurações).
   - `monospacedDigit()` para os números não "pularem" de largura durante a animação.
   - Mudança de dígito com `.contentTransition(.numericText(countsDown: true))` durante o rewind e `countsDown: false` no tick normal.
6. **Botões de lanterna e câmera** (`QuickActionButton`): dois círculos (~50pt) nos cantos inferiores, fundo `.ultraThinMaterial` escuro, com SF Symbols `flashlight.off.fill` e `camera.fill`. Posição idêntica à do iOS (ajustável na calibração).
   - Toque longo na lanterna **liga a lanterna de verdade** (`AVCaptureDevice` torch), com haptic, e o ícone muda pra `flashlight.on.fill`. Isso é um detalhe de realismo enorme se alguém mexer. Se não conseguir acesso ao torch, falha silenciosamente.
   - A câmera não faz nada (ou um haptic leve).
7. **Indicador de desbloqueio**: o iOS mostra o home indicator na parte de baixo. **Não esconda o home indicator do sistema**, ele é real e aumenta o realismo. Use `.defersSystemGestures(on: .bottom)` para o primeiro swipe da borda inferior não sair do app.

### 5.2 Transição "acordar a tela"

- Do preto para a tela de bloqueio: fade de ~0,25s com uma leve escala do wallpaper (1.03 → 1.0), imitando o wake do iOS.
- Brilho: ao entrar no `dark`, salve o brilho atual; não precisa baixar (preto em OLED já é apagado). Ao acordar, garanta que o brilho é o salvo. Restaure o brilho original ao sair do app.

### 5.3 Modo de calibração (`CalibrationView`) — essencial pra ficar idêntico

Sem isso, nunca vai ficar perfeito, porque cada iPhone e cada tela de bloqueio é diferente.

- Eu tiro um **print da minha tela de bloqueio real** e carrego no app (PhotosPicker).
- A calibração mostra a tela falsa com o **print sobreposto com opacidade ajustável** (slider 0–100%) e um botão de alternar rápido (segura pra ver o print, solta pra ver o falso).
- Sliders e steppers para ajustar ao vivo:
  - relógio: tamanho, peso (ultraLight…black), design (default/rounded/serif/monospaced), espaçamento entre letras, posição Y, cor
  - data: tamanho, peso, posição Y, opacidade
  - status bar: posição Y, tamanho da fonte, espaçamento lateral
  - cadeado: posição Y, tamanho
  - botões inferiores: tamanho, distância da borda inferior e lateral
- Para conseguir comparar com o print, a calibração congela a hora mostrada num valor que eu digito (ex.: a mesma hora do print).
- Botão "Restaurar padrões".
- Tudo salvo em `AppSettings` automaticamente.

---

## 6. A animação de voltar no tempo (`RewindPlanner`)

- **Gatilho** configurável:
  - Swipe pra cima na metade inferior da tela (padrão), começando acima dos 40pt finais (pra não brigar com o gesto do sistema).
  - Toque duplo no relógio.
  - Automático X segundos depois de acender (X configurável, padrão desligado).
- **Sequência**: o relógio desce **um minuto por vez**, de `real + N` até `real`.
- **Timing**: curva de easing aplicada ao intervalo entre passos. Começa devagar, acelera no meio e desacelera no final, criando suspense. Configuração: duração total (padrão 3,5s para qualquer N; para N=1 use no mínimo 1,2s). O `RewindPlanner` recebe N e a duração e devolve o array de intervalos entre passos. Teste unitário garantindo soma ≈ duração e intervalos todos positivos.
- **O alvo é dinâmico**: se o minuto real virar durante a animação, o destino final é a hora real **no momento em que a animação termina**. Nunca termine 1 minuto fora. Teste isso.
- **Data**: se a sequência cruzar a meia-noite, a data muda no passo certo.
- **Efeitos opcionais** (cada um com liga/desliga, todos sutis por padrão):
  - Haptic leve (`.light`) a cada minuto e um haptic `.success`/`.rigid` ao terminar.
  - Leve "glitch": deslocamento horizontal de 1–2pt e flash de opacidade no relógio a cada passo.
  - Wallpaper com zoom lento (1.0 → 1.04) durante o rewind e volta ao normal no fim.
  - Cadeado abrindo no início do rewind.
- Ao terminar → estado `live`: relógio sincronizado com a hora real e andando normalmente, para sempre. Nada no app pode depois "voltar" ou "pular".

---

## 7. Configurações (`SettingsView`)

- **Acesso secreto**, só a partir do estado `dark`: **três toques com dois dedos** em menos de 1,5s. Alternativa configurável: toque longo de 3s no canto superior esquerdo.
- Tela de configurações normal (`Form`, `NavigationStack`), em português, organizada em seções:
  1. **Entrada secreta**: modo (A/B/C), haptic de confirmação, indicador visual, modo treino.
  2. **Tela de bloqueio**: wallpaper, escurecimento, operadora, sinal, Wi-Fi, porcentagem da bateria, cadeado, formato 12/24h, zero à esquerda, formato da data, capitalização.
  3. **Calibração**: abre a `CalibrationView`.
  4. **Rewind**: gatilho, duração, efeitos.
  5. **Comportamento**: voltar ao preto quando o app volta do background; impedir o bloqueio automático da tela (`isIdleTimerDisabled`, padrão ligado enquanto o app está aberto); gesto de reset no estado `live`.
  6. **Ensaiar**: botão que simula um número aleatório e roda o fluxo completo com a grade visível.
  7. **Sobre/diagnóstico**: versão, modelo do aparelho, tamanho da tela, safe areas (útil pra calibrar).
- Todas as configurações em `AppSettings` com chaves centralizadas (enum de chaves) e valores padrão num lugar só.
- Imagens (wallpaper e print de calibração) salvas como JPEG no diretório Documents pelo `WallpaperStore`, não no UserDefaults.

---

## 8. Robustez e detalhes que entregam a mágica se estiverem errados

- **Launch screen preta** e primeira tela do app = `dark`. Abrir o app nunca pode piscar branco.
- **Status bar sempre escondida** (`.statusBarHidden(true)` na raiz + Info.plist). A hora real na status bar entregaria o segredo na hora.
- `isIdleTimerDisabled = true` enquanto o app está ativo (configurável), pra tela não apagar no meio do efeito. Desligue quando o app for pro background.
- Ao voltar do background (`scenePhase`), voltar para `dark` (configurável).
- Nenhum alerta, toast, banner, botão visível ou texto de debug nas telas `dark`, `lockScreen`, `rewinding` e `live`. Nada.
- Desempenho: nenhuma animação travando; o relógio usa `drawingGroup()` se precisar.
- Diferentes iPhones: tudo posicionado relativo às safe areas e ao tamanho da tela, nunca com coordenadas absolutas fixas. Considere SE (botão home, sem Dynamic Island; a status bar falsa continua **sem** mostrar hora), 13 mini, 15 e 15 Pro Max. **A status bar falsa nunca mostra a hora, em nenhum aparelho.**
- Modo escuro/claro do sistema não pode afetar as telas da mágica (forçar `.preferredColorScheme(.dark)` nelas).
- Acessibilidade: se o "Texto em Negrito" ou tamanho de fonte do sistema estiver alterado, as telas da mágica **não** podem mudar (use tamanhos fixos, sem Dynamic Type nelas). As configurações podem usar Dynamic Type normalmente.

---

## 9. CI no GitHub Actions (`.github/workflows/build.yml`)

### 9.1 Job `build-ipa`

- `runs-on: macos-latest`; disparo em `push` na `main` e `workflow_dispatch`.
- Passos:
  1. checkout
  2. imprimir versão do Xcode e listar Xcodes disponíveis (`ls /Applications | grep Xcode`) para diagnóstico
  3. instalar o XcodeGen (`brew install xcodegen`)
  4. `xcodegen generate`
  5. build Release para dispositivo, sem assinatura:
     ```
     xcodebuild -project TimeRewind.xcodeproj -scheme TimeRewind -configuration Release \
       -sdk iphoneos -destination 'generic/platform=iOS' \
       -derivedDataPath build \
       CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" \
       build | tee build.log
     ```
     (use `set -o pipefail` para a falha do xcodebuild falhar o job)
  6. empacotar: criar `Payload/`, copiar o `.app` de `build/Build/Products/Release-iphoneos/`, `zip -r TimeRewind.ipa Payload`
  7. `actions/upload-artifact@v4` com o `.ipa` (nome com o número do run)
  8. sempre (`if: always()`) subir o `build.log` como artifact, pra eu te mandar quando der erro
- Ao falhar, o log precisa deixar o erro fácil de achar: adicione um passo `if: failure()` que faz `grep -n "error:" build.log | head -50` e imprime no resumo do job (`$GITHUB_STEP_SUMMARY`).

### 9.2 Job `tests`

- Roda os testes unitários num simulador iPhone (`xcodebuild test`, destination com o primeiro simulador iPhone disponível; descubra dinamicamente com `xcrun simctl list devices available` para não quebrar quando a versão do runner mudar).
- Erros de teste também vão para o `$GITHUB_STEP_SUMMARY`.

### 9.3 Job `screenshots` — pra eu ver o app sem precisar instalar

Isso economiza muitos ciclos. Implemente:
- O app aceita **launch arguments** de demonstração, tratados pelo `DemoStateLauncher` (só compilado/ativo quando o argumento existe):
  - `-demoState dark-grid` (preto com grade de treino)
  - `-demoState lock -demoOffset 8 -demoTime 14:30` (tela de bloqueio com hora fixa)
  - `-demoState rewinding-mid` (meio da animação, congelado)
  - `-demoState live -demoTime 14:22`
  - `-demoState settings`
  - `-demoState calibration`
- O job compila para simulador, inicia um iPhone (ex.: iPhone 15 Pro ou o mais próximo disponível), instala o app, abre cada estado com `xcrun simctl launch ... <args>`, espera ~3s e tira um print com `xcrun simctl io booted screenshot`.
- Sobe todos os prints como artifact `screenshots`.
- Se possível, repita para um iPhone SE para conferir layout em tela pequena.

### 9.4 Ícone do app

- Gere um `AppIcon` 1024x1024 simples e discreto (ex.: fundo amarelo-claro com linhas, parecendo um app de notas). Crie o PNG por um script (Python com Pillow que eu rodo, ou gerado na própria CI no macOS com Swift/CoreGraphics via `swift script.swift`). Escolha o caminho mais confiável e documente.
- Se o ícone der problema na compilação, o app sem ícone é aceitável: **a compilação nunca pode falhar por causa do ícone**.

---

## 10. Testes unitários (obrigatórios)

Mínimo:
- `TimeEngineTests`: viradas de hora, dia, mês, ano; DST; truncamento ao minuto; formatação 12/24h, zero à esquerda, data pt-BR.
- `SecretInputTests`: mapeamento da grade em 4 tamanhos de tela; modo A, B e C; timeouts; reset; entradas inválidas no modo C.
- `RewindPlannerTests`: soma dos intervalos ≈ duração; N=1 e N=59; alvo dinâmico quando o minuto vira durante a animação.

---

## 11. Documentação

### `README.md` (português, passo a passo pra leigo, eu estou no Windows)

1. Criar o repositório no GitHub (privado ou público; explicar que público tem minutos de CI ilimitados e privado tem cota mensal de macOS) e subir o código.
2. Onde ver a CI rodando e como baixar o `.ipa` em Actions → run → Artifacts.
3. Como ver os screenshots gerados pela CI.
4. Instalar no iPhone com **Sideloadly** no Windows:
   - instalar o **iTunes baixado direto do site da Apple** (não o da Microsoft Store)
   - conectar o iPhone por cabo e confiar no computador
   - arrastar o `.ipa`, colocar o Apple ID, Start
   - no iPhone: **Ajustes → Privacidade e Segurança → Modo Desenvolvedor** (ativar e reiniciar)
   - **Ajustes → Geral → VPN e Gerenciamento de Dispositivos** → confiar no seu Apple ID
5. Limitações do Apple ID grátis: o app expira em **7 dias** (reinstalar antes de apresentações); máximo de 3 apps sideloaded ao mesmo tempo.
6. Primeira configuração: escolher wallpaper, tirar print da tela de bloqueio real e fazer a calibração.
7. O que fazer quando a CI falhar: baixar o `build.log` (ou copiar o resumo do job) e colar no Claude Code.

### `docs/COMO_APRESENTAR.md`

Roteiro de apresentação:
- Preparação: abrir o app, deixar no preto, **bloquear o iPhone de verdade**. Na hora, desbloquear pelo Face ID e o app já está lá "apagado".
- Ao vivo: pedir o número, inserir o número pelo método secreto com um toque natural, acender, criar suspense, disparar o rewind, mandar todo mundo checar os próprios celulares.
- Dicas de misdirection e de fala; o que fazer se errar o número (reset de dois dedos e "deixa eu tentar de novo, o tempo é teimoso").
- Checklist pré-show: app instalado e dentro dos 7 dias, bateria, wallpaper igual ao real, calibração conferida, modo treino desligado, notificações silenciadas (Foco/Não Perturbe) pra nenhum banner real aparecer em cima.

### `docs/DECISOES.md`

Registro curto de toda decisão que você tomar sozinho (contexto → decisão → motivo).

---

## 12. Ordem de execução (faça por fases, com commit ao final de cada uma)

1. **Fase 1 — Fundação**: `project.yml`, estrutura de pastas, app mínimo (tela preta), `.gitignore`, workflow com o job `build-ipa`. Objetivo: **a primeira CI já gerar um `.ipa` que abre**. Pare aqui e me diga para fazer o push e conferir.
2. **Fase 2 — Núcleo**: `TimeEngine`, `SecretInput`, `RewindPlanner`, `TrickState`, `TrickController` + todos os testes unitários + job `tests`.
3. **Fase 3 — Tela de bloqueio**: todas as camadas da seção 5, transição de acordar, animação de rewind completa.
4. **Fase 4 — Configurações e calibração**: seção 7 e 5.3, `WallpaperStore`, lanterna.
5. **Fase 5 — Screenshots e polimento**: `DemoStateLauncher`, job `screenshots`, ícone, revisão completa de robustez (seção 8).
6. **Fase 6 — Documentação**: README, COMO_APRESENTAR, DECISOES.

Ao final de **cada** fase:
- Revise todos os arquivos tocados procurando erros de compilação (seção 0).
- Confirme que todo arquivo `.swift` novo está coberto pelos `sources` do `project.yml`.
- Me dê um resumo curto: o que foi feito, o que eu preciso fazer (push, conferir CI, testar algo no iPhone), e qual é a próxima fase.

## 13. Critérios de aceite finais

- [ ] A CI gera um `.ipa` sem assinatura que instala via Sideloadly e abre sem crash.
- [ ] Abrir o app mostra preto puro, sem flash branco e sem status bar.
- [ ] Os três modos de entrada secreta funcionam e têm testes.
- [ ] A tela de bloqueio falsa, depois de calibrada, fica visualmente igual à real lado a lado.
- [ ] A hora mostrada é sempre `real + N` e continua andando até o rewind.
- [ ] O rewind termina **exatamente** na hora real, inclusive se o minuto virar durante a animação.
- [ ] Viradas de hora/dia/mês/ano funcionam (testes passando).
- [ ] Depois do rewind, o relógio fica sincronizado com a hora real indefinidamente.
- [ ] Configurações só acessíveis pelo gesto secreto; nada de UI visível nas telas da mágica.
- [ ] Screenshots de todos os estados aparecem nos artifacts da CI.
- [ ] README permite a um leigo no Windows instalar tudo sem me perguntar nada.

Comece pela **Fase 1**.
