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
}
