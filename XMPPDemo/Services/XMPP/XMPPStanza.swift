import Foundation

// MARK: - XMPPElement

/// Immutable, Sendable representation of a parsed XML element.
/// Acts as the universal currency between the parser and the stanza layer.
nonisolated struct XMPPElement: Sendable {
    let name: String
    let attributes: [String: String]
    let children: [XMPPElement]
    let text: String

    // MARK: Attribute Access

    subscript(attribute key: String) -> String? {
        attributes[key]
    }

    // MARK: Child Access

    func child(named name: String) -> XMPPElement? {
        children.first { $0.name.localName == name.localName }
    }

    func children(named name: String) -> [XMPPElement] {
        children.filter { $0.name.localName == name.localName }
    }

    func hasChild(named name: String) -> Bool {
        children.contains { $0.name.localName == name.localName }
    }

    /// First matching child in a namespace (e.g. xmlns="jabber:iq:roster")
    func child(xmlns: String) -> XMPPElement? {
        children.first { $0.attributes["xmlns"] == xmlns }
    }
}

// MARK: - String Helper

nonisolated private extension String {
    /// Strips namespace prefix: "stream:features" → "features"
    var localName: String {
        let parts = split(separator: ":", maxSplits: 1)
        return parts.count == 2 ? String(parts[1]) : self
    }
}

// MARK: - Chat States (XEP-0085)

nonisolated enum ChatState: String, CaseIterable, Sendable {
    case active, composing, paused, inactive, gone
}

// MARK: - XMPPStanza

/// Strongly-typed XMPP stanza derived from a raw `XMPPElement`.
nonisolated enum XMPPStanza: Sendable {

    // Stream-level
    case streamFeatures(XMPPElement)
    case streamError(condition: String)

    // TLS
    case proceed

    // SASL
    case saslSuccess
    case saslFailure(condition: String)
    case saslChallenge(encoded: String)

    // Core stanzas
    case message(from: String, to: String, id: String, body: String, requestReceipt: Bool, receiptID: String?, e2eeCiphertext: String?)
    case presence(from: String, show: String?, status: String?, type: String?, e2eePubKey: String?)
    case iq(id: String, type: String, element: XMPPElement)

    // XEP-0085 Chat States
    case chatState(from: String, state: ChatState)

    // XEP-0198 Stream Management
    case smEnabled(id: String, resume: Bool)
    case smResumed(previd: String, h: UInt32)
    case smFailed
    case smAckRequest
    case smAck(h: UInt32)

    case unknown(XMPPElement)

    // MARK: - Parser Factory

    static func parse(_ element: XMPPElement) -> XMPPStanza {
        let localName = element.name.components(separatedBy: ":").last ?? element.name

        switch localName {

        case "features":
            return .streamFeatures(element)

        case "error" where element.name.hasPrefix("stream"):
            let condition = element.children.first?.name ?? "undefined-condition"
            return .streamError(condition: condition)

        case "proceed":
            return .proceed

        case "success":
            return .saslSuccess

        case "failure":
            let condition = element.children.first?.name ?? "not-authorized"
            return .saslFailure(condition: condition)

        case "challenge":
            return .saslChallenge(encoded: element.text)
            
        case "enabled", "resumed", "failed", "r", "a":
            if let smStanza = parseStreamManagement(localName, element: element) {
                return smStanza
            }
            return .unknown(element)

        case "message":
            let type = element[attribute: "type"] ?? "normal"
            if type == "error" { return .unknown(element) } // Ignore bounced errors from offline users

            let from = element[attribute: "from"] ?? ""
            let to   = element[attribute: "to"]   ?? ""
            let id   = element[attribute: "id"]   ?? UUID().uuidString

            // XEP-0085: chat state notification without body
            for state in ChatState.allCases where element.hasChild(named: state.rawValue) {
                // Only treat as chat-state-only if no body text
                if element.child(named: "body")?.text.trimmingCharacters(in: .whitespaces).isEmpty != false {
                    return .chatState(from: from, state: state)
                }
            }

            // XEP-0184: Delivery Receipts
            let requestReceipt = element.hasChild(named: "request")
            let receiptID = element.child(named: "received")?[attribute: "id"]

            let body = element.child(named: "body")?.text.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let e2eeCiphertext = element.child(named: "e2ee")?.text
            return .message(from: from, to: to, id: id, body: body, requestReceipt: requestReceipt, receiptID: receiptID, e2eeCiphertext: e2eeCiphertext)

        case "presence":
            let from   = element[attribute: "from"] ?? ""
            let type   = element[attribute: "type"]
            let show   = element.child(named: "show")?.text
            let status = element.child(named: "status")?.text
            let e2eePubKey = element.child(named: "e2ee-pubkey")?.text
            return .presence(from: from, show: show, status: status, type: type, e2eePubKey: e2eePubKey)

        case "iq":
            let id   = element[attribute: "id"]   ?? UUID().uuidString
            let type = element[attribute: "type"] ?? "get"
            return .iq(id: id, type: type, element: element)

        default:
            return .unknown(element)
        }
    }

    private static func parseStreamManagement(_ localName: String, element: XMPPElement) -> XMPPStanza? {
        guard element.attributes.values.contains("urn:xmpp:sm:3") else { return nil }

        switch localName {
        case "enabled":
            let id = element.attributes["id"] ?? ""
            let resume = element.attributes["resume"] == "true" || element.attributes["resume"] == "1"
            return .smEnabled(id: id, resume: resume)
        case "resumed":
            let previd = element.attributes["previd"] ?? ""
            let h = UInt32(element.attributes["h"] ?? "0") ?? 0
            return .smResumed(previd: previd, h: h)
        case "failed":
            return .smFailed
        case "r":
            return .smAckRequest
        case "a":
            let h = UInt32(element.attributes["h"] ?? "0") ?? 0
            return .smAck(h: h)
        default:
            return nil
        }
    }
}
