import Foundation
import os

/// Loggers centralizados (os.Logger). Nada de print espalhado.
enum AppLog {
    static let subsystem = Bundle.main.bundleIdentifier ?? "com.magic.timerewind"

    static let trick = Logger(subsystem: subsystem, category: "Trick")
    static let input = Logger(subsystem: subsystem, category: "SecretInput")
    static let rewind = Logger(subsystem: subsystem, category: "Rewind")
}
