import AVFoundation
import Observation

/// Lanterna de verdade (botão da tela de bloqueio). Falha em silêncio se não houver acesso.
@MainActor
@Observable
final class Torch {
    private(set) var isOn: Bool = false

    func toggle() {
        setOn(!isOn)
    }

    func setOn(_ on: Bool) {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else {
            isOn = false
            return
        }
        do {
            try device.lockForConfiguration()
            if on {
                try device.setTorchModeOn(level: AVCaptureDevice.maxAvailableTorchLevel)
            } else {
                device.torchMode = .off
            }
            device.unlockForConfiguration()
            isOn = on
        } catch {
            AppLog.trick.error("Lanterna indisponível")
        }
    }
}
