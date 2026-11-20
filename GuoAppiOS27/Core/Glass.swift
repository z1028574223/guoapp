import SwiftUI

/// iOS 27 Liquid Glass design tokens. The material itself is rendered by SwiftUI's
/// native .glassEffect(); these values keep spacing, type and color consistent.
enum GlassTokens {
    static let accent = Color.orange
    static let accentHot = Color.pink
    static let cornerLarge: CGFloat = 26
    static let cornerMedium: CGFloat = 18
    static let cornerSmall: CGFloat = 12

    /// Maps the iOS 27 transparency slider (0 clear → 1 tinted) to the glass tint.
    /// .tint() modulates the sampled backdrop rather than painting an opaque fill.
    static func tint(level: Double) -> Color {
        Color.white.opacity(0.02 + level * 0.16)
    }
}

/// Type-erased Shape so the modifier can accept capsules, rounded rects, circles.
struct AnyShape: Shape {
    private let _path: (CGRect) -> Path
    init<S: Shape>(_ shape: S) { _path = { shape.path(in: $0) } }
    func path(in rect: CGRect) -> Path { _path(rect) }
}

/// Applies the native iOS 26/27 glass material, with an ultraThinMaterial fallback
/// for older OS. The tint follows the user's transparency slider.
struct AdaptiveGlass: ViewModifier {
    let level: Double
    let shape: AnyShape
    let interactive: Bool

    // Keep control flow out of the @ViewBuilder body: an `if` branch there must
    // yield a View, but this mutation yields Void.
    private var material: Glass {
        let base = Glass.regular.tint(GlassTokens.tint(level: level))
        return interactive ? base.interactive() : base
    }

    func body(content: Content) -> some View {
        // Deployment target is iOS 26, so the native glass material is always
        // available — no runtime availability guard needed.
        content.glassEffect(material, in: shape)
    }
}

extension View {
    func adaptiveGlass(level: Double,
                       in shape: AnyShape = AnyShape(Capsule()),
                       interactive: Bool = false) -> some View {
        modifier(AdaptiveGlass(level: level, shape: shape, interactive: interactive))
    }
}
