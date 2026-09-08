import SwiftUI

enum ReadinessColorScale {
    static func color(for score: Double) -> Color {
        let normalized = min(max(score, 0), 100) / 100
        return Color(
            hue: normalized * 0.33,
            saturation: 0.82,
            brightness: 0.90
        )
    }

    static let gradient = LinearGradient(
        colors: stride(from: 0.0, through: 100.0, by: 20.0).map(color(for:)),
        startPoint: .leading,
        endPoint: .trailing
    )
}
