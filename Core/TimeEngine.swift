import Foundation

/// Opções de formatação da hora do relógio da tela de bloqueio.
struct ClockFormatOptions: Equatable {
    /// true = 24h (padrão); false = 12h sem AM/PM, igual à tela de bloqueio do iOS.
    var uses24Hour: Bool = true
    /// Zero à esquerda na hora ("09:41" em vez de "9:41").
    var leadingZeroHour: Bool = true
}

/// Opções de formatação da data acima do relógio.
struct DateFormatOptions: Equatable {
    var format: String = TimeEngine.defaultDateFormat
    var localeIdentifier: String = TimeEngine.defaultLocaleIdentifier
    /// Deixa a primeira letra maiúscula ("Quinta-feira, 8 de outubro").
    var capitalizeFirstLetter: Bool = false
}

/// Lógica pura de tempo. Nunca chama Date() internamente: `now` e `calendar`
/// sempre chegam por parâmetro, para os testes serem determinísticos.
enum TimeEngine {
    static let defaultDateFormat = "EEEE, d 'de' MMMM"
    static let defaultLocaleIdentifier = "pt_BR"

    /// Hora "falsa": real + offset minutos (sem truncar).
    static func displayedDate(now: Date, offsetMinutes: Int) -> Date {
        now.addingTimeInterval(TimeInterval(offsetMinutes) * 60)
    }

    /// Início do minuto que contém `date` (segundos e frações zerados).
    static func truncatedToMinute(_ date: Date, calendar: Calendar) -> Date {
        if let interval = calendar.dateInterval(of: .minute, for: date) {
            return interval.start
        }
        let seconds = floor(date.timeIntervalSinceReferenceDate / 60) * 60
        return Date(timeIntervalSinceReferenceDate: seconds)
    }

    /// Minuto exibido na tela: (real + offset) truncado ao minuto.
    static func displayedMinute(now: Date, offsetMinutes: Int, calendar: Calendar) -> Date {
        truncatedToMinute(displayedDate(now: now, offsetMinutes: offsetMinutes), calendar: calendar)
    }

    /// Próxima borda de minuto estritamente depois de `date`.
    static func nextMinuteBoundary(after date: Date, calendar: Calendar) -> Date {
        truncatedToMinute(date, calendar: calendar).addingTimeInterval(60)
    }

    /// Texto do relógio, ex.: "14:03", "09:41" ou "9:41".
    static func timeString(for date: Date, calendar: Calendar, options: ClockFormatOptions) -> String {
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        var displayHour = hour
        if !options.uses24Hour {
            displayHour = hour % 12
            if displayHour == 0 {
                displayHour = 12
            }
        }
        let hourText = options.leadingZeroHour ? twoDigits(displayHour) : String(displayHour)
        return hourText + ":" + twoDigits(minute)
    }

    /// Texto da data, ex.: "quinta-feira, 8 de outubro".
    static func dateString(for date: Date, calendar: Calendar, options: DateFormatOptions) -> String {
        let formatter = DateFormatterCache.shared.formatter(
            format: options.format,
            localeIdentifier: options.localeIdentifier,
            calendar: calendar
        )
        let text = formatter.string(from: date)
        guard options.capitalizeFirstLetter, let first = text.first else {
            return text
        }
        let locale = Locale(identifier: options.localeIdentifier)
        return String(first).uppercased(with: locale) + String(text.dropFirst())
    }

    private static func twoDigits(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }
}

/// Cache de DateFormatter: cada combinação é criada uma única vez.
final class DateFormatterCache {
    static let shared = DateFormatterCache()

    private var formatters: [String: DateFormatter] = [:]
    private let lock = NSLock()

    func formatter(format: String, localeIdentifier: String, calendar: Calendar) -> DateFormatter {
        let key = "\(format)|\(localeIdentifier)|\(calendar.identifier)|\(calendar.timeZone.identifier)"
        lock.lock()
        defer { lock.unlock() }
        if let cached = formatters[key] {
            return cached
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: localeIdentifier)
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = format
        formatters[key] = formatter
        return formatter
    }
}

// MARK: - Codable tolerante (campos ausentes usam o padrão)

extension ClockFormatOptions: Codable {
    enum CodingKeys: String, CodingKey {
        case uses24Hour, leadingZeroHour
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = ClockFormatOptions()
        self.init()
        uses24Hour = container.value(.uses24Hour, default: fallback.uses24Hour)
        leadingZeroHour = container.value(.leadingZeroHour, default: fallback.leadingZeroHour)
    }
}

extension DateFormatOptions: Codable {
    enum CodingKeys: String, CodingKey {
        case format, localeIdentifier, capitalizeFirstLetter
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = DateFormatOptions()
        self.init()
        format = container.value(.format, default: fallback.format)
        localeIdentifier = container.value(.localeIdentifier, default: fallback.localeIdentifier)
        capitalizeFirstLetter = container.value(.capitalizeFirstLetter, default: fallback.capitalizeFirstLetter)
    }
}
