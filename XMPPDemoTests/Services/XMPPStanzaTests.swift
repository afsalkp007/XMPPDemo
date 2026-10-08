import XCTest
@testable import XMPPDemo

final class XMPPStanzaTests: XCTestCase {
    func testParsesChatMessage() {
        let message = XMPPElement(
            name: "message",
            attributes: ["from": "alice@localhost/phone", "to": "bob@localhost", "id": "message-1"],
            children: [XMPPElement(name: "body", attributes: [:], children: [], text: "Hello")],
            text: ""
        )

        guard case let .message(from, to, id, body, requestsReceipt, receiptID) = XMPPStanza.parse(message) else {
            return XCTFail("Expected a chat message")
        }

        XCTAssertEqual(from, "alice@localhost/phone")
        XCTAssertEqual(to, "bob@localhost")
        XCTAssertEqual(id, "message-1")
        XCTAssertEqual(body, "Hello")
        XCTAssertFalse(requestsReceipt)
        XCTAssertNil(receiptID)
    }

    func testParsesDeliveryReceipt() {
        let message = XMPPElement(
            name: "message",
            attributes: [:],
            children: [XMPPElement(name: "received", attributes: ["id": "message-1"], children: [], text: "")],
            text: ""
        )

        guard case let .message(_, _, _, body, _, receiptID) = XMPPStanza.parse(message) else {
            return XCTFail("Expected a receipt message")
        }

        XCTAssertTrue(body.isEmpty)
        XCTAssertEqual(receiptID, "message-1")
    }

    func testParsesTypingIndicator() {
        let message = XMPPElement(
            name: "message",
            attributes: ["from": "alice@localhost"],
            children: [XMPPElement(name: "composing", attributes: [:], children: [], text: "")],
            text: ""
        )

        guard case let .chatState(from, state) = XMPPStanza.parse(message) else {
            return XCTFail("Expected a chat-state message")
        }

        XCTAssertEqual(from, "alice@localhost")
        XCTAssertEqual(state, .composing)
    }

    func testParsesUploadSlotResponse() throws {
        let response = XMPPElement(
            name: "iq",
            attributes: ["type": "result"],
            children: [
                XMPPElement(
                    name: "slot",
                    attributes: [:],
                    children: [
                        XMPPElement(name: "put", attributes: ["url": "https://localhost:5443/upload/file.jpg"], children: [], text: ""),
                        XMPPElement(name: "get", attributes: ["url": "https://localhost:5443/upload/file.jpg"], children: [], text: "")
                    ],
                    text: ""
                )
            ],
            text: ""
        )

        let slot = try HTTPUploadSlot(response: response)

        XCTAssertEqual(slot.putURL.absoluteString, "https://localhost:5443/upload/file.jpg")
        XCTAssertEqual(slot.getURL.absoluteString, "https://localhost:5443/upload/file.jpg")
    }

    func testRejectsMalformedUploadSlotResponse() {
        let response = XMPPElement(name: "iq", attributes: ["type": "result"], children: [], text: "")

        XCTAssertThrowsError(try HTTPUploadSlot(response: response)) { error in
            XCTAssertEqual(error as? HTTPUploadSlotError, .malformedResponse)
        }
    }
    
    func testParsesStreamFeatures() {
        let el = XMPPElement(name: "stream:features", attributes: [:], children: [], text: "")
        guard case let .streamFeatures(features) = XMPPStanza.parse(el) else {
            return XCTFail()
        }
        XCTAssertEqual(features.name, "stream:features")
    }
    
    func testParsesProceed() {
        let el = XMPPElement(name: "proceed", attributes: ["xmlns": "urn:ietf:params:xml:ns:xmpp-tls"], children: [], text: "")
        guard case .proceed = XMPPStanza.parse(el) else { return XCTFail() }
    }
    
    func testParsesSASLSuccess() {
        let el = XMPPElement(name: "success", attributes: ["xmlns": "urn:ietf:params:xml:ns:xmpp-sasl"], children: [], text: "")
        guard case .saslSuccess = XMPPStanza.parse(el) else { return XCTFail() }
    }
    
    func testParsesSASLFailure() {
        let el = XMPPElement(name: "failure", attributes: ["xmlns": "urn:ietf:params:xml:ns:xmpp-sasl"], children: [
            XMPPElement(name: "not-authorized", attributes: [:], children: [], text: "")
        ], text: "")
        guard case let .saslFailure(reason) = XMPPStanza.parse(el) else { return XCTFail() }
        XCTAssertEqual(reason, "not-authorized")
    }
    
    func testParsesSMResumed() {
        let el = XMPPElement(name: "resumed", attributes: ["xmlns": "urn:xmpp:sm:3", "previd": "abc", "h": "10"], children: [], text: "")
        guard case let .smResumed(id, h) = XMPPStanza.parse(el) else { return XCTFail() }
        XCTAssertEqual(id, "abc")
        XCTAssertEqual(h, 10)
    }
    
    func testParsesSMFailed() {
        let el = XMPPElement(name: "failed", attributes: ["xmlns": "urn:xmpp:sm:3"], children: [], text: "")
        guard case .smFailed = XMPPStanza.parse(el) else { return XCTFail() }
    }
    
    func testParsesSMAckRequest() {
        let el = XMPPElement(name: "r", attributes: ["xmlns": "urn:xmpp:sm:3"], children: [], text: "")
        guard case .smAckRequest = XMPPStanza.parse(el) else { return XCTFail() }
    }
    
    func testParsesSMAck() {
        let el = XMPPElement(name: "a", attributes: ["xmlns": "urn:xmpp:sm:3", "h": "5"], children: [], text: "")
        guard case let .smAck(h) = XMPPStanza.parse(el) else { return XCTFail() }
        XCTAssertEqual(h, 5)
    }
}
