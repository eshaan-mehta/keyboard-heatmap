import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xff) / 255,
                  green: Double((hex >> 8) & 0xff) / 255,
                  blue: Double(hex & 0xff) / 255,
                  opacity: 1)
    }
}

/// Black-and-white chrome. Color is reserved for data marks.
enum Palette {
    static let background = Color.white
    static let ink = Color(hex: 0x111111)
    static let inkSecondary = Color(hex: 0x6b6b6b)
    static let muted = Color(hex: 0x9b9b9b)
    static let hairline = Color(hex: 0xe8e8e8)
    static let wash = Color(hex: 0xf6f6f6)
    static let keyIdle = Color(hex: 0xefefef)
    static let context = Color(hex: 0xd6d6d6)   // de-emphasized bars

    // Data accents. One calm blue for series; the warm end of the heat ramp
    // only where something is "hot".
    static let accentBlue = Color(hex: 0x4f6fc7)
    static let accentWarm = Color(hex: 0xe0953a)
    static let accentRed = Color(hex: 0xd3452e)
    static let good = Color(hex: 0x2f9e5f)
    static let keyBorder = Color(hex: 0xe2e2e2)
}

/// Heat overlay in the classic order, blue → green → yellow → orange → red.
/// Vivid hues applied as a translucent wash over white keycaps: the least
/// pressed keys are a pale tint of their color, the hottest go solid red.
enum Heat {
    struct RGB {
        var r: Double, g: Double, b: Double
        var color: Color { Color(.sRGB, red: r, green: g, blue: b, opacity: 1) }
        /// Rough perceived lightness, enough to pick a legible text color.
        var lightness: Double { 0.2126 * r + 0.7152 * g + 0.0722 * b }
    }

    static let stops: [UInt32] = [0x3d6ff0, 0x2fc06a, 0xf6c62d, 0xf5821f, 0xd92b1c]

    static func rgb(_ hex: UInt32) -> RGB {
        RGB(r: Double((hex >> 16) & 0xff) / 255, g: Double((hex >> 8) & 0xff) / 255, b: Double(hex & 0xff) / 255)
    }

    /// Pure ramp color at `t`, before the wash is applied.
    static func hue(_ t: Double) -> RGB {
        let clamped = min(max(t, 0), 1)
        let pos = clamped * Double(stops.count - 1)
        let i = Int(pos.rounded(.down))
        let j = min(i + 1, stops.count - 1)
        let f = pos - Double(i)
        let a = rgb(stops[i]), b = rgb(stops[j])
        return RGB(r: a.r + (b.r - a.r) * f, g: a.g + (b.g - a.g) * f, b: a.b + (b.b - a.b) * f)
    }

    /// Ramp color washed over white. Opacity rises slowly at first, so lightly
    /// used keys stay close to white, then steeply, so hot keys go solid.
    static func sample(_ t: Double) -> RGB {
        let c = hue(t)
        let clamped = min(max(t, 0), 1)
        let alpha = 0.10 + 0.90 * pow(clamped, 1.25)
        return RGB(r: 1 - (1 - c.r) * alpha, g: 1 - (1 - c.g) * alpha, b: 1 - (1 - c.b) * alpha)
    }

    static func color(_ t: Double) -> Color { sample(t).color }

    static var gradient: LinearGradient {
        let colors = stride(from: 0.0, through: 1.0, by: 1.0 / 12).map { sample($0).color }
        return LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing)
    }
}
