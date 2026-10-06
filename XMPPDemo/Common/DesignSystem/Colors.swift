import SwiftUI

// MARK: - Background Hierarchy
extension Color {
    nonisolated static let bgPrimary   = Color(red: 0.067, green: 0.075, blue: 0.098)   // #111318
    nonisolated static let bgSurface   = Color(red: 0.100, green: 0.110, blue: 0.141)   // #1A1C24
    nonisolated static let bgElevated  = Color(red: 0.137, green: 0.153, blue: 0.196)   // #232732
    nonisolated static let bgBorder    = Color(red: 0.196, green: 0.216, blue: 0.271)   // #323745
}

// MARK: - Brand Colors
extension Color {
    /// Primary cyan accent: #08C8E0
    nonisolated static let brandCyan     = Color(red: 0.031, green: 0.784, blue: 0.878)
    /// Dimmer variant for gradients
    nonisolated static let brandCyanDeep = Color(red: 0.020, green: 0.545, blue: 0.635)
    /// Teal for outgoing message bubbles
    nonisolated static let brandTeal     = Color(red: 0.039, green: 0.588, blue: 0.686)
}

// MARK: - Text
extension Color {
    nonisolated static let textPrimary   = Color.white
    nonisolated static let textSecondary = Color(red: 0.573, green: 0.612, blue: 0.706)
    nonisolated static let textTertiary  = Color(red: 0.376, green: 0.408, blue: 0.482)
    nonisolated static let textInverse   = Color(red: 0.067, green: 0.075, blue: 0.098)
}

// MARK: - Bubbles
extension Color {
    nonisolated static let bubbleOut = Color(red: 0.039, green: 0.588, blue: 0.686)
    nonisolated static let bubbleIn  = Color(red: 0.165, green: 0.184, blue: 0.235)
}

// MARK: - Presence
extension Color {
    nonisolated static let presenceOnline  = Color(red: 0.118, green: 0.784, blue: 0.439)   // #1EC870
    nonisolated static let presenceAway    = Color(red: 0.949, green: 0.604, blue: 0.122)   // #F29A1F
    nonisolated static let presenceBusy    = Color(red: 0.902, green: 0.275, blue: 0.275)   // #E64646
    nonisolated static let presenceOffline = Color(red: 0.376, green: 0.408, blue: 0.482)
}

// MARK: - Semantic
extension Color {
    nonisolated static let errorRed     = Color(red: 0.933, green: 0.275, blue: 0.275)
    nonisolated static let successGreen = Color(red: 0.118, green: 0.784, blue: 0.439)
    nonisolated static let warningAmber = Color(red: 0.949, green: 0.604, blue: 0.122)
}

// MARK: - Gradients
extension LinearGradient {
    nonisolated static let brand = LinearGradient(
        colors: [.brandCyan, .brandCyanDeep],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    nonisolated static let appBackground = LinearGradient(
        colors: [Color(red: 0.067, green: 0.075, blue: 0.110), Color(red: 0.039, green: 0.043, blue: 0.078)],
        startPoint: .top,
        endPoint: .bottom
    )
    nonisolated static let loginHero = LinearGradient(
        colors: [
            Color(red: 0.043, green: 0.051, blue: 0.082),
            Color(red: 0.020, green: 0.027, blue: 0.059),
            Color(red: 0.031, green: 0.059, blue: 0.098)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - ShapeStyle shortcuts
// Isolated Color statics are not visible through ShapeStyle member lookup.
extension ShapeStyle where Self == Color {
    nonisolated static var bgPrimary: Color { .bgPrimary }
    nonisolated static var bgSurface: Color { .bgSurface }
    nonisolated static var bgElevated: Color { .bgElevated }
    nonisolated static var bgBorder: Color { .bgBorder }
    nonisolated static var brandCyan: Color { .brandCyan }
    nonisolated static var brandCyanDeep: Color { .brandCyanDeep }
    nonisolated static var brandTeal: Color { .brandTeal }
    nonisolated static var textPrimary: Color { .textPrimary }
    nonisolated static var textSecondary: Color { .textSecondary }
    nonisolated static var textTertiary: Color { .textTertiary }
    nonisolated static var textInverse: Color { .textInverse }
    nonisolated static var bubbleOut: Color { .bubbleOut }
    nonisolated static var bubbleIn: Color { .bubbleIn }
    nonisolated static var presenceOnline: Color { .presenceOnline }
    nonisolated static var presenceAway: Color { .presenceAway }
    nonisolated static var presenceBusy: Color { .presenceBusy }
    nonisolated static var presenceOffline: Color { .presenceOffline }
    nonisolated static var errorRed: Color { .errorRed }
    nonisolated static var successGreen: Color { .successGreen }
    nonisolated static var warningAmber: Color { .warningAmber }
}
