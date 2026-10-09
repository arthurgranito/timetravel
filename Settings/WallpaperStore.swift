import UIKit
import Observation

/// Salva e carrega as imagens (wallpaper e print de calibração) como JPEG no Documents.
@MainActor
@Observable
final class WallpaperStore {
    enum Kind: String {
        case wallpaper
        case calibration

        var fileName: String { "\(rawValue).jpg" }
    }

    private(set) var wallpaper: UIImage?
    private(set) var calibrationImage: UIImage?

    /// Maior lado salvo, em pixels (suficiente para qualquer iPhone).
    private let maxPixelSide: CGFloat = 3000

    init() {
        wallpaper = load(.wallpaper)
        calibrationImage = load(.calibration)
    }

    func image(for kind: Kind) -> UIImage? {
        switch kind {
        case .wallpaper:
            return wallpaper
        case .calibration:
            return calibrationImage
        }
    }

    /// Recebe os bytes vindos do PhotosPicker. Devolve false se não for uma imagem válida.
    @discardableResult
    func save(_ data: Data, as kind: Kind) -> Bool {
        guard let original = UIImage(data: data) else { return false }
        let image = normalized(original)
        guard let jpeg = image.jpegData(compressionQuality: 0.92) else { return false }
        do {
            try jpeg.write(to: url(for: kind), options: .atomic)
        } catch {
            AppLog.trick.error("Falha ao salvar imagem")
            return false
        }
        set(image, for: kind)
        return true
    }

    func remove(_ kind: Kind) {
        try? FileManager.default.removeItem(at: url(for: kind))
        set(nil, for: kind)
    }

    private func set(_ image: UIImage?, for kind: Kind) {
        switch kind {
        case .wallpaper:
            wallpaper = image
        case .calibration:
            calibrationImage = image
        }
    }

    private func load(_ kind: Kind) -> UIImage? {
        guard let data = try? Data(contentsOf: url(for: kind)) else { return nil }
        return UIImage(data: data)
    }

    private func url(for kind: Kind) -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent(kind.fileName)
    }

    /// Aplica a orientação da foto e reduz se for maior que `maxPixelSide`.
    private func normalized(_ image: UIImage) -> UIImage {
        let pixelWidth = image.size.width * image.scale
        let pixelHeight = image.size.height * image.scale
        let largest = max(pixelWidth, pixelHeight)
        let factor = largest > maxPixelSide ? maxPixelSide / largest : 1
        let target = CGSize(width: floor(pixelWidth * factor), height: floor(pixelHeight * factor))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: target, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
