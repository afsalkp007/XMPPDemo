import SwiftUI

// MARK: - App Font Scale
extension Font {
    // Display
    static let appDisplay     = Font.system(size: 36, weight: .bold,     design: .rounded)
    static let appLargeTitle  = Font.system(size: 28, weight: .bold,     design: .rounded)
    static let appTitle       = Font.system(size: 22, weight: .semibold, design: .rounded)
    static let appTitle2      = Font.system(size: 18, weight: .semibold, design: .rounded)

    // Body
    static let appHeadline    = Font.system(size: 16, weight: .semibold, design: .default)
    static let appBody        = Font.system(size: 15, weight: .regular,  design: .default)
    static let appBodyMedium  = Font.system(size: 15, weight: .medium,   design: .default)
    static let appSubheadline = Font.system(size: 13, weight: .regular,  design: .default)

    // Captions
    static let appCaption     = Font.system(size: 12, weight: .medium,   design: .default)
    static let appCaption2    = Font.system(size: 11, weight: .regular,  design: .default)

    // Monospaced (timestamps, JIDs)
    static let appMono        = Font.system(size: 12, weight: .regular,  design: .monospaced)
    static let appTimestamp   = Font.system(size: 11, weight: .regular,  design: .monospaced)

    // Messaging
    static let messageBubble  = Font.system(size: 15, weight: .regular,  design: .default)
    static let messageInput   = Font.system(size: 16, weight: .regular,  design: .default)
}

// MARK: - Text Modifiers
struct PrimaryTextStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.appBody)
            .foregroundStyle(Color.textPrimary)
    }
}

struct SecondaryTextStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.appSubheadline)
            .foregroundStyle(Color.textSecondary)
    }
}

extension View {
    func primaryTextStyle()   -> some View { modifier(PrimaryTextStyle()) }
    func secondaryTextStyle() -> some View { modifier(SecondaryTextStyle()) }
}
