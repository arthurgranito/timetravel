import PhotosUI
import SwiftUI

/// Configurações (só abre pelo gesto secreto na tela preta).
struct SettingsView: View {
    @Bindable var settings: AppSettings
    let wallpapers: WallpaperStore
    /// Usado pelo estado de demonstração "calibration".
    var opensCalibrationOnAppear: Bool = false
    let onRehearse: @MainActor () -> Void
    let onClose: @MainActor () -> Void

    @State private var wallpaperItem: PhotosPickerItem?
    @State private var showsCalibration = false
    @State private var showsResetConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                inputSection
                lockScreenSection
                calibrationSection
                rewindSection
                behaviorSection
                rehearsalSection
                aboutSection
            }
            .navigationTitle("Configurações")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Concluir") {
                        onClose()
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showsCalibration) {
            CalibrationView(settings: settings, wallpapers: wallpapers)
        }
        .onAppear {
            if opensCalibrationOnAppear {
                showsCalibration = true
            }
        }
        .onChange(of: wallpaperItem) { _, item in
            loadWallpaper(item)
        }
        .confirmationDialog("Restaurar todas as configurações?", isPresented: $showsResetConfirmation, titleVisibility: .visible) {
            Button("Restaurar tudo", role: .destructive) {
                settings.resetAll()
            }
            Button("Cancelar", role: .cancel) {}
        }
    }

    // MARK: - 1. Entrada secreta

    private var inputSection: some View {
        Section {
            Picker("Modo", selection: $settings.data.inputMode) {
                ForEach(SecretInputMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            Picker("Haptic de confirmação", selection: $settings.data.preferences.haptics.secretMode) {
                ForEach(SecretHapticMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            if settings.data.inputMode == .tapCount {
                Toggle("Batida a cada toque contado", isOn: $settings.data.preferences.haptics.tapCountTicks)
            }
            if settings.data.inputMode != .grid {
                Stepper(value: $settings.data.inputTimeout, in: 2...15, step: 1) {
                    Text("Zerar após \(Int(settings.data.inputTimeout))s parado")
                }
            }
            Toggle("Indicador visual (ponto discreto)", isOn: $settings.data.preferences.showsSecretIndicator)
            Toggle("Modo treino (grade visível)", isOn: $settings.data.preferences.showsTrainingGrid)
            Picker("Abrir configurações", selection: $settings.data.settingsGesture) {
                ForEach(SettingsGesture.allCases) { gesture in
                    Text(gesture.label).tag(gesture)
                }
            }
        } header: {
            Text("Entrada secreta")
        } footer: {
            Text(inputFooter)
        }
    }

    private var inputFooter: String {
        switch settings.data.inputMode {
        case .grid:
            return "Um toque na posição do número (teclado de telefone) guarda o número; o segundo toque, em qualquer lugar, acende a tela. Dois dedos segurando 1,5s zeram tudo."
        case .tapCount:
            return "Cada toque rápido soma 1. Um toque longo (0,6s) confirma e acende a tela. Dois dedos segurando 1,5s zeram tudo."
        case .twoStepGrid:
            return "Primeiro toque = dezena (0 a 5; o 0 fica no centro, abaixo da grade). Segundo toque = unidade. Terceiro toque acende a tela."
        }
    }

    // MARK: - 2. Tela de bloqueio

    private var lockScreenSection: some View {
        Section("Tela de bloqueio") {
            HStack(spacing: 12) {
                wallpaperThumbnail
                VStack(alignment: .leading, spacing: 8) {
                    PhotosPicker(selection: $wallpaperItem, matching: .images) {
                        Label("Escolher wallpaper", systemImage: "photo")
                    }
                    if wallpapers.wallpaper != nil {
                        Button("Remover wallpaper", role: .destructive) {
                            wallpapers.remove(.wallpaper)
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
            VStack(alignment: .leading) {
                Text("Escurecimento: \(Int(settings.data.style.wallpaperDim * 100))%")
                Slider(value: $settings.data.style.wallpaperDim, in: 0...0.3)
            }
            Group {
                TextField("Operadora", text: $settings.data.style.carrierName)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Stepper(value: $settings.data.style.signalBars, in: 0...4) {
                    Text("Sinal: \(settings.data.style.signalBars)/4")
                }
                Toggle("Wi-Fi", isOn: $settings.data.style.showsWiFi)
                Toggle("Porcentagem na bateria", isOn: $settings.data.style.showsBatteryPercentage)
                Toggle("Cadeado", isOn: $settings.data.style.showsPadlock)
            }
            Group {
                Toggle("Formato 24 horas", isOn: $settings.data.style.clockFormat.uses24Hour)
                Toggle("Zero à esquerda na hora", isOn: $settings.data.style.clockFormat.leadingZeroHour)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Formato da data")
                TextField("Formato", text: $settings.data.style.dateFormat.format)
                    .font(.body.monospaced())
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Text("Prévia: \(datePreview)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Group {
                Toggle("Primeira letra maiúscula", isOn: $settings.data.style.dateFormat.capitalizeFirstLetter)
                Toggle("Texto \"Deslize para cima para abrir\"", isOn: $settings.data.style.showsUnlockHint)
                Button("Formato de data padrão") {
                    settings.data.style.dateFormat.format = TimeEngine.defaultDateFormat
                }
            }
        }
    }

    @ViewBuilder
    private var wallpaperThumbnail: some View {
        if let image = wallpapers.wallpaper {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 46, height: 92)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(LinearGradient(colors: [Color(white: 0.2), Color(white: 0.05)], startPoint: .top, endPoint: .bottom))
                .frame(width: 46, height: 92)
        }
    }

    private var datePreview: String {
        TimeEngine.dateString(for: Date(), calendar: Calendar.autoupdatingCurrent, options: settings.data.style.dateFormat)
    }

    // MARK: - 3. Calibração

    private var calibrationSection: some View {
        Section {
            Button {
                showsCalibration = true
            } label: {
                Label("Abrir calibração", systemImage: "square.on.square.dashed")
            }
        } header: {
            Text("Calibração")
        } footer: {
            Text("Tire um print da sua tela de bloqueio real, carregue na calibração e ajuste até o falso ficar idêntico.")
        }
    }

    // MARK: - 4. Rewind

    private var rewindSection: some View {
        Section("Rewind") {
            Picker("Gatilho", selection: $settings.data.preferences.rewindTrigger) {
                ForEach(RewindTrigger.allCases) { trigger in
                    Text(trigger.label).tag(trigger)
                }
            }
            if settings.data.preferences.rewindTrigger == .automatic {
                Stepper(value: $settings.data.preferences.autoRewindDelay, in: 1...30, step: 1) {
                    Text("Começar \(Int(settings.data.preferences.autoRewindDelay))s depois de acender")
                }
            }
            Picker("Ritmo", selection: $settings.data.rewindPacing) {
                ForEach(RewindPacing.allCases) { pacing in
                    Text(pacing.label).tag(pacing)
                }
            }
            switch settings.data.rewindPacing {
            case .totalDuration:
                VStack(alignment: .leading) {
                    Text("Duração total: \(String(format: "%.1f", settings.data.rewindDuration))s")
                    Slider(value: $settings.data.rewindDuration, in: RewindPlanner.minimumDuration...10, step: 0.1)
                }
            case .fixedRhythm:
                VStack(alignment: .leading) {
                    Text("Segundos por minuto: \(String(format: "%.1f", settings.data.secondsPerMinute))s")
                    Slider(
                        value: $settings.data.secondsPerMinute,
                        in: RewindPlanner.secondsPerMinuteRange,
                        step: 0.1
                    )
                }
            case .stepByStep:
                Text("Um minuto por segundo, sempre no mesmo ritmo. Bom para contar junto com a plateia.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Toggle("Haptic a cada minuto", isOn: $settings.data.preferences.haptics.rewindSteps)
            Toggle("Haptic ao terminar", isOn: $settings.data.preferences.haptics.rewindFinish)
            Toggle("Glitch no relógio", isOn: $settings.data.preferences.effects.glitch)
            Toggle("Zoom lento do wallpaper", isOn: $settings.data.preferences.effects.wallpaperZoom)
            Toggle("Cadeado abrindo", isOn: $settings.data.preferences.effects.padlockOpens)
        }
    }

    // MARK: - 5. Comportamento

    private var behaviorSection: some View {
        Section("Comportamento") {
            Toggle("Voltar ao preto ao sair do app", isOn: $settings.data.returnToDarkOnBackground)
            Toggle("Impedir bloqueio automático da tela", isOn: $settings.data.preferences.keepScreenAwake)
            Toggle("Toque longo volta ao preto (depois do rewind)", isOn: $settings.data.preferences.liveResetEnabled)
            if settings.data.preferences.liveResetEnabled {
                Stepper(value: $settings.data.preferences.liveResetDuration, in: 0.5...5, step: 0.5) {
                    Text("Segurar \(String(format: "%.1f", settings.data.preferences.liveResetDuration))s")
                }
            }
        }
    }

    // MARK: - 6. Ensaiar

    private var rehearsalSection: some View {
        Section {
            Button {
                onRehearse()
            } label: {
                Label("Ensaiar agora", systemImage: "play.circle")
            }
        } header: {
            Text("Ensaiar")
        } footer: {
            Text("Sorteia um número e volta para a tela preta com a grade visível. Faça a entrada, acenda e dispare o rewind. A grade some sozinha ao final.")
        }
    }

    // MARK: - 7. Sobre / diagnóstico

    private var aboutSection: some View {
        Section("Sobre / diagnóstico") {
            LabeledContent("Versão", value: DeviceInfo.appVersion)
            LabeledContent("Modelo", value: DeviceInfo.modelIdentifier)
            LabeledContent("Sistema", value: DeviceInfo.systemVersion)
            LabeledContent("Tela", value: DeviceInfo.screenDescription)
            LabeledContent("Safe areas", value: DeviceInfo.safeAreaDescription)
            Button("Restaurar todas as configurações", role: .destructive) {
                showsResetConfirmation = true
            }
        }
    }

    // MARK: - Ações

    private func loadWallpaper(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self) {
                wallpapers.save(data, as: .wallpaper)
            }
            wallpaperItem = nil
        }
    }
}
