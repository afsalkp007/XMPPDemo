import XCTest
@testable import XMPPDemo

final class XMPPStreamParserTests: XCTestCase {
    func testParsesStreamOpeningAttributes() {
        let parser = XMPPStreamParser()
        var opened: (id: String, domain: String)?
        parser.onStreamOpened = { id, domain in opened = (id, domain) }

        parser.receive(data: data("<stream:stream from='localhost' id='stream-1' xmlns:stream='http://etherx.jabber.org/streams'>"))

        XCTAssertEqual(opened?.id, "stream-1")
        XCTAssertEqual(opened?.domain, "localhost")
    }

    func testDoesNotEmitFragmentedMessageUntilComplete() {
        let parser = openedParser()
        var stanzas: [XMPPElement] = []
        parser.onStanza = { stanzas.append($0) }

        parser.receive(data: data("<message from='alice@localhost'><body>Hel"))
        XCTAssertTrue(stanzas.isEmpty)

        parser.receive(data: data("lo</body></message>"))
        XCTAssertEqual(stanzas.count, 1)
        XCTAssertEqual(stanzas.first?.child(named: "body")?.text, "Hello")
    }

    func testEmitsEachStanzaWhenMultipleArriveTogether() {
        let parser = openedParser()
        var names: [String] = []
        parser.onStanza = { names.append($0.name) }

        parser.receive(data: data("<message><body>Hello</body></message><presence/>"))

        XCTAssertEqual(names, ["message", "presence"])
    }

    func testEmitsSelfClosingStanza() {
        let parser = openedParser()
        var stanza: XMPPElement?
        parser.onStanza = { stanza = $0 }

        parser.receive(data: data("<proceed xmlns='urn:ietf:params:xml:ns:xmpp-tls'/>"))

        XCTAssertEqual(stanza?.name, "proceed")
    }

    private func openedParser() -> XMPPStreamParser {
        let parser = XMPPStreamParser()
        parser.receive(data: data("<stream:stream from='localhost' id='stream-1' xmlns:stream='http://etherx.jabber.org/streams'>"))
        return parser
    }

    private func data(_ string: String) -> Data {
        Data(string.utf8)
    }
}
