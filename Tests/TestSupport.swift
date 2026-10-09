import Foundation
import CoreGraphics
@testable import TimeRewind

/// Utilidades compartilhadas pelos testes.
enum TestSupport {
    static func calendar(_ timeZoneIdentifier: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneIdentifier) ?? TimeZone(secondsFromGMT: 0)!
        calendar.locale = Locale(identifier: "pt_BR")
        return calendar
    }

    /// Data no fuso do calendário informado.
    static func date(
        _ calendar: Calendar,
        _ year: Int, _ month: Int, _ day: Int,
        _ hour: Int, _ minute: Int, _ second: Int = 0,
        nanosecond: Int = 0
    ) -> Date {
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = second
        components.nanosecond = nanosecond
        return calendar.date(from: components)!
    }

    /// Data em UTC (para instantes ambíguos de horário de verão).
    static func utc(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int, _ second: Int = 0) -> Date {
        date(calendar("UTC"), year, month, day, hour, minute, second)
    }

    struct Device {
        let name: String
        let canvas: InputCanvas
    }

    /// Tamanhos de tela (pt) e safe areas em retrato.
    static let devices: [Device] = [
        Device(name: "iPhone SE", canvas: InputCanvas(
            size: CGSize(width: 375, height: 667),
            safeAreaInsets: CanvasInsets(top: 20, leading: 0, bottom: 0, trailing: 0))),
        Device(name: "iPhone 13 mini", canvas: InputCanvas(
            size: CGSize(width: 375, height: 812),
            safeAreaInsets: CanvasInsets(top: 50, leading: 0, bottom: 34, trailing: 0))),
        Device(name: "iPhone 15", canvas: InputCanvas(
            size: CGSize(width: 393, height: 852),
            safeAreaInsets: CanvasInsets(top: 59, leading: 0, bottom: 34, trailing: 0))),
        Device(name: "iPhone 15 Pro Max", canvas: InputCanvas(
            size: CGSize(width: 430, height: 932),
            safeAreaInsets: CanvasInsets(top: 59, leading: 0, bottom: 34, trailing: 0)))
    ]

    /// Centro da célula de um dígito, calculado de forma independente do código de produção.
    static func center(of digit: Int, canvas: InputCanvas, rows: Int, margin: CGFloat = 40) -> CGPoint {
        let insets = canvas.safeAreaInsets
        let left = insets.leading
        let top = insets.top + margin
        let width = canvas.size.width - insets.leading - insets.trailing
        let height = canvas.size.height - insets.top - insets.bottom - 2 * margin
        let column: Int
        let row: Int
        if digit == 0 {
            column = 1
            row = 3
        } else {
            column = (digit - 1) % 3
            row = (digit - 1) / 3
        }
        return CGPoint(
            x: left + (CGFloat(column) + 0.5) * width / 3,
            y: top + (CGFloat(row) + 0.5) * height / CGFloat(rows)
        )
    }
}
