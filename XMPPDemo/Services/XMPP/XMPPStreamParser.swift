import Foundation

// MARK: - XMPPStreamParser
//
// Incrementally parses XMPP's never-ending XML stream into discrete XMPPElement stanzas.
//
// XMPP stream structure:
//  <?xml version="1.0"?>
//  <stream:stream to="domain" ...>   ← opening tag, never explicitly closed by server
//    <stream:features>...</stream:features>
//    <proceed/>
//    <success/>
//    <message>...</message>
//    ...
//  </stream:stream>
//
// Responsibilities:
//  1. Strip XML declaration
//  2. Detect <stream:stream> opening and fire onStreamOpened
//  3. Extract complete child stanzas and fire onStanza
//  4. Detect </stream:stream> and fire onStreamClosed
//
// Not thread-safe — all calls must originate from the same serial context (actor).

nonisolated final class XMPPStreamParser: NSObject, XMLParserDelegate {

    // MARK: - Callbacks

    var onStreamOpened: ((String, String) -> Void)?  // (streamID, from-domain)
    var onStanza: ((XMPPElement) -> Void)?
    var onStreamClosed: (() -> Void)?

    // MARK: - Private State

    private var textBuffer  = ""
    private var streamOpened = false

    // SAX accumulation
    private var elementStack: [MutableElement] = []
    private var parsedRoot: XMPPElement?

    // MARK: - Mutable SAX Builder

    private final class MutableElement {
        let name: String
        let attributes: [String: String]
        var children: [XMPPElement] = []
        var text: String = ""

        init(name: String, attributes: [String: String]) {
            self.name = name
            self.attributes = attributes
        }

        func freeze() -> XMPPElement {
            XMPPElement(
                name: name,
                attributes: attributes,
                children: children,
                text: text.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
    }

    // MARK: - Public Entry Point

    /// Feed raw bytes from the network here.
    func receive(data: Data) {
        guard let str = String(data: data, encoding: .utf8) else { return }
        textBuffer += str
        process()
    }

    // MARK: - Processing Pipeline

    private func process() {
        stripXMLDeclaration()
        parseStreamOpening()

        guard streamOpened else { return }

        while true {
            textBuffer = textBuffer.trimmingCharacters(in: .whitespacesAndNewlines)

            // Check for stream close before looking for a stanza
            if textBuffer.hasPrefix("</stream:stream") {
                onStreamClosed?()
                textBuffer = ""
                return
            }

            guard let stanzaXML = extractNextStanza() else { break }

            if let element = parseSAX(stanzaXML) {
                onStanza?(element)
            }
        }
    }

    // MARK: Step 1: Strip XML Declaration

    private func stripXMLDeclaration() {
        // May arrive split across packets, so only strip when complete
        while textBuffer.hasPrefix("<?xml") {
            guard let end = textBuffer.range(of: "?>") else { return }
            textBuffer.removeSubrange(..<end.upperBound)
        }
    }

    // MARK: Step 2: Detect <stream:stream ...>

    private func parseStreamOpening() {
        guard !streamOpened else { return }
        guard let streamStart = textBuffer.range(of: "<stream:stream") else { return }
        guard let tagEnd = textBuffer.range(of: ">", range: streamStart.upperBound..<textBuffer.endIndex) else {
            return  // Incomplete — wait for more data
        }
        let openTag = String(textBuffer[..<tagEnd.upperBound])
        let id   = extractAttr("id",   from: openTag) ?? UUID().uuidString
        let from = extractAttr("from", from: openTag) ?? ""
        streamOpened = true
        textBuffer.removeSubrange(..<tagEnd.upperBound)
        onStreamOpened?(id, from)
    }

    // MARK: Step 3: Extract One Complete Stanza

    /// Removes and returns the next complete XML stanza from `textBuffer`, or nil if incomplete.
    private func extractNextStanza() -> String? {
        // Trim ONLY leading whitespace (Ejabberd often sends newlines between stanzas).
        // Do NOT trim trailing whitespace, as it might belong to an incomplete text node.
        while let first = textBuffer.first, first.isWhitespace {
            textBuffer.removeFirst()
        }
        
        guard textBuffer.hasPrefix("<"), !textBuffer.hasPrefix("</") else { return nil }

        var depth = 0
        var idx = textBuffer.startIndex
        var inTag = false
        var tagContent = ""

        while idx < textBuffer.endIndex {
            let ch = textBuffer[idx]

            if ch == "<" {
                inTag = true
                tagContent = ""
            } else if ch == ">" && inTag {
                inTag = false
                let content = tagContent.trimmingCharacters(in: .whitespacesAndNewlines)

                if content.hasPrefix("/") {
                    // </close>
                    depth -= 1
                    if depth == 0 {
                        let endIdx = textBuffer.index(after: idx)
                        let stanza = String(textBuffer[..<endIdx])
                        textBuffer = String(textBuffer[endIdx...])
                        return stanza
                    }
                } else if content.hasSuffix("/") || isSelfClosingTag(content) {
                    // <selfClose/>
                    if depth == 0 {
                        let endIdx = textBuffer.index(after: idx)
                        let stanza = String(textBuffer[..<endIdx])
                        textBuffer = String(textBuffer[endIdx...])
                        return stanza
                    }
                } else {
                    // <open>
                    depth += 1
                }
            } else if inTag {
                tagContent.append(ch)
            }

            idx = textBuffer.index(after: idx)
        }

        return nil  // Stanza not yet complete
    }

    /// Some stanzas like <proceed/> may not end with '/' but have no children — handled by depth tracking above.
    private func isSelfClosingTag(_ content: String) -> Bool {
        content.hasSuffix("/")
    }

    // MARK: Step 4: SAX Parse a Stanza String → XMPPElement

    private func parseSAX(_ xml: String) -> XMPPElement? {
        // Wrap in synthetic root so namespace declarations resolve correctly
        let wrapped = """
        <?xml version="1.0"?>\
        <_root xmlns="jabber:client" \
               xmlns:stream="http://etherx.jabber.org/streams" \
               xmlns:sasl="urn:ietf:params:xml:ns:xmpp-sasl" \
               xmlns:tls="urn:ietf:params:xml:ns:xmpp-tls">\
        \(xml)</_root>
        """
        guard let data = wrapped.data(using: .utf8) else { return nil }

        elementStack = []
        parsedRoot = nil

        let parser = XMLParser(data: data)
        parser.shouldProcessNamespaces = false
        parser.delegate = self
        parser.parse()

        return parsedRoot
    }

    // MARK: - XMLParserDelegate

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName _: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        guard elementName != "_root" else { return }
        elementStack.append(MutableElement(name: elementName, attributes: attributeDict))
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        elementStack.last?.text += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName _: String?
    ) {
        guard elementName != "_root" else { return }
        guard let completed = elementStack.popLast() else { return }
        let element = completed.freeze()

        if elementStack.isEmpty {
            parsedRoot = element        // Top-level stanza complete
        } else {
            elementStack.last?.children.append(element)
        }
    }

    // MARK: - Attribute Extraction

    /// Extracts an XML attribute value from a raw tag string.
    private func extractAttr(_ name: String, from tag: String) -> String? {
        for quote in ["\"", "'"] {
            let prefix = "\(name)=\(quote)"
            guard let start = tag.range(of: prefix) else { continue }
            guard let end = tag.range(of: quote, range: start.upperBound..<tag.endIndex) else { continue }
            return String(tag[start.upperBound..<end.lowerBound])
        }
        return nil
    }
}
