import PhotosUI
import SwiftUI

/// Grupo de ajustes mostrado no painel da calibração.
enum CalibrationGroup: String, CaseIterable, Identifiable {
    case screenshot, clock, date, statusBar, padlock, buttons

    var id: String { rawValue }

    var label: String {
        switch self {
        case .screenshot:
            return "Print"
        case .clock:
            return "Relógio"
        case .date:
            return "Data"
        case .statusBar:
            return "Barra"
        case .padlock:
            return "Cadeado"
        case .buttons:
            return "Botões"
        }
    }
}

/// Calibração: a tela falsa com o print da tela real sobreposto, e ajustes ao vivo.
struct CalibrationView: View {
    @Bindable var settings: AppSettings
    let wallpapers: WallpaperStore

    @Environment(\.dismiss) private var dismiss
    @State private var battery = BatteryMonitor()
    @State private var frozenTime = Date()
    @State private var overlayOpacity: Double = 0.5
    @State private var isPeeking = false
    @State private var showsControls = true
    @State private var group: CalibrationGroup = .screenshot
    @State private var screenshotItem: PhotosPickerItem?
    @State private var previewPadlockOpen = false
    @State private var closeRequested = false

    private let calendar = Calendar.autoupdatingCurrent

    var body: some View {
        GeometryReader { proxy in
            let metrics = ScreenMetrics(proxy: proxy)
            ZStack {
                LockScreenCanvas(
                    shownMinute: TimeEngine.truncatedToMinute(frozenTime, calendar: calendar),
                    calendar: calendar,
                    style: settings.data.style,
                    wallpaper: wallpapers.wallpaper,
                    metrics: metrics,
                    battery: battery,
                    isPadlockOpen: previewPadlockOpen,
                    showsUnlockHint: settings.data.style.showsUnlockHint
                )
                .allowsHitTesting(false)

                if let screenshot = wallpapers.calibrationImage {
                    Image(uiImage: screenshot)
                        .resizable()
                        .scaledToFill()
                        .frame(width: metrics.size.width, height: metrics.size.height)
                        .clipped()
                        .opacity(isPeeking ? 1 : overlayOpacity)
                        .allowsHitTesting(false)
                }

                if !showsControls {
                    Button {
                        showsControls = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color.white)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Color.black.opacity(0.6)))
                    }
                    .position(x: metrics.size.width / 2, y: metrics.size.height - metrics.safeBottom - 40)
                }
            }
            .frame(width: metrics.size.width, height: metrics.size.height)
        }
        .ignoresSafeArea()
        .background(Color.black)
        .statusBarHidden(true)
        .onAppear {
            battery.start()
        }
        .onChange(of: screenshotItem) { _, item in
            loadScreenshot(item)
        }
        .sheet(isPresented: $showsControls, onDismiss: {
            if closeRequested {
                dismiss()
            }
        }) {
            controlsPanel
                .presentationDetents([.height(320), .medium, .large])
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                .presentationBackground(.regularMaterial)
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Painel

    private var controlsPanel: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Button("Esconder") {
                    showsControls = false
                }
                Spacer()
                Text("Segure p/ ver o print")
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(isPeeking ? Color.accentColor : Color.secondary.opacity(0.25)))
                    .onLongPressGesture(minimumDuration: 60, maximumDistance: 80, perform: {}, onPressingChanged: { pressing in
                        isPeeking = pressing
                    })
                Spacer()
                Button("Concluir") {
                    closeRequested = true
                    showsControls = false
                }
                .fontWeight(.semibold)
            }
            .padding(.horizontal)
            .padding(.top, 14)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(CalibrationGroup.allCases) { item in
                        Button {
                            group = item
                        } label: {
                            Text(item.label)
                                .font(.subheadline.weight(.medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(group == item ? Color.accentColor.opacity(0.35) : Color.secondary.opacity(0.18)))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    groupControls
                    Divider()
                    Button("Restaurar padrões da calibração", role: .destructive) {
                        settings.data.style.resetCalibration()
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
        }
    }

    @ViewBuilder
    private var groupControls: some View {
        switch group {
        case .screenshot:
            screenshotControls
        case .clock:
            clockControls
        case .date:
            dateControls
        case .statusBar:
            statusBarControls
        case .padlock:
            padlockControls
        case .buttons:
            buttonControls
        }
    }

    private var screenshotControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                PhotosPicker(selection: $screenshotItem, matching: .screenshots) {
                    Label("Carregar print", systemImage: "photo.on.rectangle")
                }
                Spacer()
                if wallpapers.calibrationImage != nil {
                    Button("Remover", role: .destructive) {
                        wallpapers.remove(.calibration)
                    }
                }
            }
            CalibrationSlider(title: "Opacidade do print", value: $overlayOpacity, range: 0...1, step: 0.05, unit: "")
            DatePicker("Hora mostrada", selection: $frozenTime)
                .environment(\.locale, Locale(identifier: "pt_BR"))
            Toggle("Mostrar cadeado aberto", isOn: $previewPadlockOpen)
            Text("Coloque aqui a mesma hora e data do print para comparar.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var clockControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            CalibrationSlider(title: "Tamanho", value: $settings.data.style.clockSize, range: 50...170, step: 0.5)
            Picker("Peso", selection: $settings.data.style.clockWeight) {
                ForEach(FontWeightOption.allCases) { option in
                    Text(option.label).tag(option)
                }
            }
            Picker("Fonte", selection: $settings.data.style.clockDesign) {
                ForEach(FontDesignOption.allCases) { option in
                    Text(option.label).tag(option)
                }
            }
            CalibrationSlider(title: "Espaçamento", value: $settings.data.style.clockKerning, range: -8...8, step: 0.1)
            CalibrationSlider(title: "Posição vertical", value: $settings.data.style.clockYOffset, range: -200...200, step: 0.5)
            ColorPicker("Cor", selection: clockColorBinding, supportsOpacity: true)
        }
    }

    private var dateControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            CalibrationSlider(title: "Tamanho", value: $settings.data.style.dateSize, range: 10...36, step: 0.5)
            Picker("Peso", selection: $settings.data.style.dateWeight) {
                ForEach(FontWeightOption.allCases) { option in
                    Text(option.label).tag(option)
                }
            }
            CalibrationSlider(title: "Posição vertical", value: $settings.data.style.dateYOffset, range: -150...150, step: 0.5)
            CalibrationSlider(title: "Opacidade", value: $settings.data.style.dateOpacity, range: 0.3...1, step: 0.01, unit: "")
        }
    }

    private var statusBarControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            CalibrationSlider(title: "Posição vertical", value: $settings.data.style.statusBarYOffset, range: -30...30, step: 0.5)
            CalibrationSlider(title: "Tamanho da fonte", value: $settings.data.style.statusBarFontSize, range: 11...22, step: 0.25)
            CalibrationSlider(title: "Espaçamento lateral", value: $settings.data.style.statusBarSideOffset, range: -25...40, step: 0.5)
        }
    }

    private var padlockControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            CalibrationSlider(title: "Posição vertical", value: $settings.data.style.padlockYOffset, range: -60...60, step: 0.5)
            CalibrationSlider(title: "Tamanho", value: $settings.data.style.padlockSize, range: 8...32, step: 0.5)
            Toggle("Mostrar cadeado aberto", isOn: $previewPadlockOpen)
        }
    }

    private var buttonControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            CalibrationSlider(title: "Tamanho", value: $settings.data.style.quickButtonSize, range: 34...72, step: 0.5)
            CalibrationSlider(title: "Distância da base", value: $settings.data.style.quickButtonBottomOffset, range: -50...80, step: 0.5)
            CalibrationSlider(title: "Distância lateral", value: $settings.data.style.quickButtonSideOffset, range: -40...50, step: 0.5)
        }
    }

    private var clockColorBinding: Binding<Color> {
        Binding(
            get: { settings.data.style.clockColor.color },
            set: { settings.data.style.clockColor = RGBAColor($0) }
        )
    }

    private func loadScreenshot(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self) {
                wallpapers.save(data, as: .calibration)
            }
            screenshotItem = nil
        }
    }
}

/// Slider com título, valor e botões de ajuste fino (− / +).
struct CalibrationSlider<Value: BinaryFloatingPoint>: View where Value.Stride: BinaryFloatingPoint {
    let title: String
    @Binding var value: Value
    let range: ClosedRange<Value>
    var step: Value = 1
    var unit: String = " pt"

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                Text(title)
                Spacer()
                Text(formatted + unit)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Button {
                    value = max(range.lowerBound, value - step)
                } label: {
                    Image(systemName: "minus.circle")
                }
                .buttonStyle(.borderless)
                Button {
                    value = min(range.upperBound, value + step)
                } label: {
                    Image(systemName: "plus.circle")
                }
                .buttonStyle(.borderless)
            }
            Slider(value: $value, in: range)
        }
    }

    private var formatted: String {
        String(format: "%.2f", Double(value))
    }
}
