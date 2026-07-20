import SwiftUI

/// In-app splash shown over the app at cold launch. It renders the same
/// waveless image as the static launch screen (pixel-identical, so the
/// hand-off is seamless), then animates the three sound-wave arcs like a
/// loading indicator: one → two → all three → repeat.
struct SplashView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visibleArcs = 1

    private static let stepDuration: TimeInterval = 0.38
    /// Two full arc cycles before the app fades in.
    static let displayDuration: TimeInterval = 2.4

    /// Arc geometry fitted from the original artwork by
    /// Tools/remove_splash_waves.py, in display points within the
    /// 256 × 458.7 pt splash image.
    private struct WaveArc {
        let radius: CGFloat
        let lineWidth: CGFloat
        let startDegrees: Double
        let endDegrees: Double
        let color: Color
    }

    private static let arcCenter = CGPoint(x: 162.6, y: 205.2)
    private static let waveArcs: [WaveArc] = [
        WaveArc(radius: 16.5, lineWidth: 4.2, startDegrees: -72.3, endDegrees: 36.3,
                color: Color(red: 222 / 255, green: 168 / 255, blue: 89 / 255)),
        WaveArc(radius: 31.6, lineWidth: 3.8, startDegrees: -62.9, endDegrees: 28.5,
                color: Color(red: 229 / 255, green: 179 / 255, blue: 100 / 255)),
        WaveArc(radius: 47.0, lineWidth: 3.6, startDegrees: -58.9, endDegrees: 25.7,
                color: Color(red: 233 / 255, green: 186 / 255, blue: 107 / 255)),
    ]

    var body: some View {
        ZStack {
            Color("LaunchBackground")
            Image("SplashImage")
                .overlay { arcOverlay }
        }
        // Center in the FULL screen exactly like the static launch screen,
        // so the hand-off between the two is pixel-aligned.
        .ignoresSafeArea()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Table Score is loading"))
        .task {
            guard !reduceMotion else {
                visibleArcs = Self.waveArcs.count
                return
            }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(Self.stepDuration * 1_000_000_000))
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: 0.15)) {
                    visibleArcs = visibleArcs % Self.waveArcs.count + 1
                }
            }
        }
    }

    private var arcOverlay: some View {
        ZStack {
            ForEach(Array(Self.waveArcs.enumerated()), id: \.offset) { index, arc in
                ArcShape(
                    center: Self.arcCenter,
                    radius: arc.radius,
                    startAngle: .degrees(arc.startDegrees),
                    endAngle: .degrees(arc.endDegrees)
                )
                .stroke(arc.color, style: StrokeStyle(lineWidth: arc.lineWidth, lineCap: .round))
                .opacity(index < visibleArcs ? 1 : 0)
            }
        }
    }
}

private struct ArcShape: Shape {
    let center: CGPoint
    let radius: CGFloat
    let startAngle: Angle
    let endAngle: Angle

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        return path
    }
}
