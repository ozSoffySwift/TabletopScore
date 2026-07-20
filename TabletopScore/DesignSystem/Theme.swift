import SwiftUI

/// Design tokens (spec §3): near-black background, candlelight-amber accent.
/// Colors adapt to the user's appearance setting; dark is the canonical look.
enum Theme {
    static let background = Color(
        light: UIColor(red: 0xF5 / 255, green: 0xF3 / 255, blue: 0xEE / 255, alpha: 1),
        dark: UIColor(red: 0x0B / 255, green: 0x0B / 255, blue: 0x0F / 255, alpha: 1)
    )
    static let surface = Color(
        light: .white,
        dark: UIColor(red: 0x18 / 255, green: 0x18 / 255, blue: 0x1E / 255, alpha: 1)
    )
    static let surfaceElevated = Color(
        light: UIColor(red: 0xEC / 255, green: 0xE9 / 255, blue: 0xE2 / 255, alpha: 1),
        dark: UIColor(red: 0x22 / 255, green: 0x22 / 255, blue: 0x2A / 255, alpha: 1)
    )
    static let accent = Color(red: 0xE6 / 255, green: 0xA2 / 255, blue: 0x3C / 255)
    static let textPrimary = Color(
        light: UIColor(red: 0x1A / 255, green: 0x18 / 255, blue: 0x14 / 255, alpha: 1),
        dark: .white
    )
    static let textSecondary = Color(
        light: UIColor(red: 0x1A / 255, green: 0x18 / 255, blue: 0x14 / 255, alpha: 0.6),
        dark: UIColor(white: 1, alpha: 0.65)
    )
    static let cornerRadius: CGFloat = 12

    /// 2:3 portrait poster size for playlist cards.
    static let posterWidth: CGFloat = 118
    static var posterHeight: CGFloat { posterWidth * 1.5 }
}

extension Color {
    /// Dynamic color that follows the resolved light/dark appearance.
    init(light: UIColor, dark: UIColor) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }
}

extension TimeInterval {
    /// "3:24" for track scrubbers and rows.
    var trackTimeString: String {
        guard isFinite, self >= 0 else { return "0:00" }
        let total = Int(rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// "1 hr 12 min" for playlist totals.
    var longDurationString: String {
        guard isFinite, self > 0 else { return "0 min" }
        let minutes = Int((self / 60).rounded())
        if minutes < 60 { return String(localized: "\(minutes) min") }
        let hours = minutes / 60
        let rest = minutes % 60
        return rest == 0
            ? String(localized: "\(hours) hr")
            : String(localized: "\(hours) hr \(rest) min")
    }
}
