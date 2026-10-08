import XCTest
@testable import XMPPDemo

@MainActor
final class XMPPPresenceTests: XCTestCase {
    
    func testPresenceStatusParsing() {
        // Online (no show/type)
        XCTAssertEqual(PresenceStatus.from(xmppShow: nil, type: nil), .available)
        
        // Away
        XCTAssertEqual(PresenceStatus.from(xmppShow: "away", type: nil), .away)
        
        // DND
        XCTAssertEqual(PresenceStatus.from(xmppShow: "dnd", type: nil), .dnd)
        
        // XA
        XCTAssertEqual(PresenceStatus.from(xmppShow: "xa", type: nil), .xa)
        
        // Offline
        XCTAssertEqual(PresenceStatus.from(xmppShow: nil, type: "unavailable"), .offline)
        
        // Error
        XCTAssertEqual(PresenceStatus.from(xmppShow: nil, type: "error"), .offline)
    }
    
    func testStreamManagementParsing() {
        let el = XMPPElement(name: "enabled", attributes: ["xmlns": "urn:xmpp:sm:3", "id": "123", "resume": "true"], children: [], text: "")
        let stanza = XMPPStanza.parse(el)
        switch stanza {
        case .smEnabled(let id, let resume):
            XCTAssertEqual(id, "123")
            XCTAssertTrue(resume)
        default:
            XCTFail("Failed to parse SM enabled")
        }
    }
}
