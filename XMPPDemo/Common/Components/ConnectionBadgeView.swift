import SwiftUI

/// Animated banner shown at the top of screens when the connection is not active.
struct ConnectionBadgeView: View {
    let state: ConnectionState

    var body: some View {
        if !state.isConnected {
            HStack(spacing: 8) {
                if state.isTransitioning {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.7)
                        .tint(.textSecondary)
                } else {
                    Image(systemName: state.isFailed ? "exclamationmark.triangle.fill" : "wifi.slash")
                        .font(.appCaption)
                        .foregroundStyle(state.isFailed ? .errorRed : .textSecondary)
                }

                Text(state.displayName)
                    .font(.appCaption)
                    .foregroundStyle(.textSecondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(Color.bgElevated)
                    .shadow(color: .black.opacity(0.3), radius: 6, y: 2)
            )
            .transition(.move(edge: .top).combined(with: .opacity))
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: state)
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        ConnectionBadgeView(state: .connecting)
        ConnectionBadgeView(state: .reconnecting(attempt: 2))
        ConnectionBadgeView(state: .failed(reason: "Auth failed"))
        ConnectionBadgeView(state: .disconnected)
    }
    .padding()
    .background(Color.bgPrimary)
}
