import SwiftUI
import UIKit

/// Deterministic gradient artwork keyed by playlist/track id — a stand-in
/// for licensed box art (deferred; see spec §3 legal note). The same key
/// always yields the same colors, in views and in lock-screen artwork.
enum PlaceholderArt {
    private static let symbols = [
        "dice", "shield.lefthalf.filled", "crown.fill", "map.fill",
        "flame.fill", "moon.stars.fill", "gamecontroller.fill", "hourglass",
        "sparkles", "theatermasks.fill", "puzzlepiece.fill", "scroll.fill",
    ]

    private static let imageCache = NSCache<NSString, UIImage>()

    private static func hash(_ key: String) -> UInt64 {
        key.utf8.reduce(5381 as UInt64) { ($0 << 5) &+ $0 &+ UInt64($1) }
    }

    static func hues(for key: String) -> (Double, Double) {
        let h = hash(key)
        let hue = Double(h % 360) / 360
        let hue2 = (hue + 0.13).truncatingRemainder(dividingBy: 1)
        return (hue, hue2)
    }

    static func colors(for key: String) -> (Color, Color) {
        let (h1, h2) = hues(for: key)
        return (
            Color(hue: h1, saturation: 0.62, brightness: 0.52),
            Color(hue: h2, saturation: 0.7, brightness: 0.2)
        )
    }

    static func gradient(for key: String) -> LinearGradient {
        let (top, bottom) = colors(for: key)
        return LinearGradient(
            colors: [top, bottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func symbolName(for key: String) -> String {
        symbols[Int(hash(key) % UInt64(symbols.count))]
    }

    /// Rendered UIImage for MPNowPlayingInfoCenter artwork.
    static func image(for key: String, side: CGFloat = 600) -> UIImage {
        let cacheKey = "\(key)-\(Int(side))" as NSString
        if let cached = imageCache.object(forKey: cacheKey) { return cached }

        let (h1, h2) = hues(for: key)
        let top = UIColor(hue: h1, saturation: 0.62, brightness: 0.52, alpha: 1)
        let bottom = UIColor(hue: h2, saturation: 0.7, brightness: 0.2, alpha: 1)
        let size = CGSize(width: side, height: side)

        let image = UIGraphicsImageRenderer(size: size).image { context in
            let colors = [top.cgColor, bottom.cgColor] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
                context.cgContext.drawLinearGradient(
                    gradient,
                    start: .zero,
                    end: CGPoint(x: size.width, y: size.height),
                    options: []
                )
            }
            let config = UIImage.SymbolConfiguration(pointSize: side * 0.3, weight: .medium)
            if let symbol = UIImage(systemName: symbolName(for: key), withConfiguration: config)?
                .withTintColor(.white.withAlphaComponent(0.35), renderingMode: .alwaysOriginal) {
                let origin = CGPoint(
                    x: (size.width - symbol.size.width) / 2,
                    y: (size.height - symbol.size.height) / 2
                )
                symbol.draw(at: origin)
            }
        }
        imageCache.setObject(image, forKey: cacheKey)
        return image
    }
}
