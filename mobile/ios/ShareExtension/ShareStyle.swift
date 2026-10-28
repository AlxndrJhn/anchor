import SwiftUI
import UIKit

struct ShareStyle {
    let colors: AnchorColors
    let isCompact: Bool

    init(scheme: ColorScheme, isCompact: Bool) {
        colors = scheme == .dark ? .dark : .light
        self.isCompact = isCompact
    }

    var space8: CGFloat { isCompact ? AnchorTokens.densityCompactSpace8 : AnchorTokens.densityDefaultSpace8 }
    var space12: CGFloat { isCompact ? AnchorTokens.densityCompactSpace12 : AnchorTokens.densityDefaultSpace12 }
    var space16: CGFloat { isCompact ? AnchorTokens.densityCompactSpace16 : AnchorTokens.densityDefaultSpace16 }
    var control: CGFloat { isCompact ? AnchorTokens.densityCompactControl : AnchorTokens.densityDefaultControl }

    var note: AnchorNoteColors { colors.notes[AnchorTokens.defaultNotePalette]! }

    /// A tag's #, as tag_colors.dart picks it.
    func hash(of stored: String?) -> Color {
        let hex = "#" + (stored ?? "").uppercased().replacingOccurrences(of: "#", with: "")
        let palette = AnchorTokens.tagNames[hex] ?? "blueGrey"
        return colors.tags[palette]!.hash
    }
}

/// As Pressable and DisabledOpacity in the app.
enum Press {
    static let buttonScale: CGFloat = 0.97
    static let plainOpacity: Double = 0.55
    static let disabledButton: Double = 0.4
}

enum Springs {
    static let smooth = spring(AnchorTokens.motionSpringSmoothDuration, AnchorTokens.motionSpringSmoothBounce)
    static let snappy = spring(AnchorTokens.motionSpringSnappyDuration, AnchorTokens.motionSpringSnappyBounce)

    private static func spring(_ duration: TimeInterval, _ bounce: CGFloat) -> Animation {
        .spring(response: duration, dampingFraction: 1 - bounce)
    }
}

extension Font {
    static func anchor(_ style: AnchorTextStyle, weight: Int? = nil) -> Font {
        let size = style.size
        let variations: [Int: CGFloat] = [
            0x7767_6874: CGFloat(weight ?? style.weight), // wght
            0x6F70_737A: min(max(size, 9), 40), // opsz
        ]
        let descriptor = UIFontDescriptor(fontAttributes: [
            .family: "DM Sans",
            UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String): variations,
        ])
        return Font(UIFontMetrics.default.scaledFont(for: UIFont(descriptor: descriptor, size: size)))
    }
}

extension Text {
    func anchor(_ style: AnchorTextStyle, weight: Int? = nil, color: Color) -> some View {
        font(.anchor(style, weight: weight))
            .tracking(style.tracking)
            .lineSpacing(style.size * (style.lineHeight - 1))
            .foregroundColor(color)
    }
}

struct IconView: View {
    let icon: AnchorIcon
    let size: CGFloat
    let color: Color

    var body: some View {
        icon.path
            .applying(CGAffineTransform(scaleX: size / 24, y: size / 24))
            .stroke(color, style: StrokeStyle(lineWidth: 2 * size / 24, lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// The app's strings, from Localizable.xcstrings.
enum L {
    static func text(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }

    static func text(_ key: String, _ value: String) -> String {
        String(format: NSLocalizedString(key, comment: ""), value)
    }

    static func count(_ key: String, _ count: Int) -> String {
        String.localizedStringWithFormat(NSLocalizedString(key, comment: ""), count)
    }
}

extension View {
    func shadows(_ shadows: [AnchorShadow]) -> some View {
        shadows.reduce(AnyView(self)) { view, shadow in
            AnyView(view.shadow(color: shadow.color, radius: shadow.blur / 2, x: shadow.x, y: shadow.y))
        }
    }
}
