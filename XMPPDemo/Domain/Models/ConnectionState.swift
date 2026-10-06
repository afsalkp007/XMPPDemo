import Foundation

/// Models the lifecycle of an XMPP stream connection.
nonisolated enum ConnectionState: Equatable, Sendable {
    case disconnected
    case connecting
    case connected
    case reconnecting(attempt: Int)
    case failed(reason: String)

    // MARK: - Display

    var displayName: String {
        switch self {
        case .disconnected:           return "Offline"
        case .connecting:             return "Connecting…"
        case .connected:              return "Connected"
        case .reconnecting(let n):    return "Reconnecting (\(n))…"
        case .failed(let r):          return r
        }
    }

    // MARK: - State Queries

    var isConnected: Bool {
        guard case .connected = self else { return false }
        return true
    }

    var isTransitioning: Bool {
        switch self {
        case .connecting, .reconnecting: return true
        default: return false
        }
    }

    var isFailed: Bool {
        guard case .failed = self else { return false }
        return true
    }
}
