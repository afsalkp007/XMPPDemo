import Foundation

// MARK: - XMPPManager
//
// Swift actor that owns the entire XMPP session lifecycle:
//   TCP connect → STARTTLS → SASL PLAIN → Resource Binding → Active session
//
// Transport: CFStreamCreatePairWithSocketToHost (supports mid-stream STARTTLS upgrade)
// Concurrency: actor isolation + StreamBridge for RunLoop→async bridging
// Events:  AsyncStream-based (connectionStateStream, inboundMessageStream, etc.)

actor XMPPManager: XMPPMessageSending, XMPPUploadSlotRequesting {

    // MARK: - Public AsyncStreams

    private let (connectionStateStream, _connCont):    (AsyncStream<ConnectionState>,                               AsyncStream<ConnectionState>.Continuation)

    // Callers subscribe to this
    nonisolated let connectionState: AsyncStream<ConnectionState>

    // MARK: - Connection Phase

    private enum Phase {
        case disconnected
        case tcpConnected       // TCP open, stream:stream sent
        case tlsHandshaking     // STARTTLS sent, waiting for <proceed/>
        case tlsNegotiated      // TLS active, new stream:stream sent
        case saslSent           // SASL <auth> sent
        case saslSucceeded      // <success> received, new stream:stream sent
        case binding            // <iq bind> sent
        case smEnabling         // <enable> sent
        case smResuming         // <resume> sent
        case active             // Fully operational
    }

    // MARK: - Private State

    private var phase: Phase = .disconnected

    // Network
    private var worker: StreamWorker?
    private var parser = XMPPStreamParser()

    // Session
    private var myBareJID  = ""
    private var myFullJID  = ""
    private var domain     = ""
    private var password   = ""
    private var resource   = "XMPPDemo-iOS"

    // Roster cache
    private var contacts: [String: Contact] = [:]

    // Pending IQ callbacks keyed by stanza id
    private var iqCallbacks: [String: CheckedContinuation<XMPPElement, Error>] = [:]

    // Track outgoing subscriptions to prevent infinite loops when auto-accepting
    private var pendingSubscriptions: Set<String> = []

    // Heartbeat Task
    private var pingTask: Task<Void, Never>?

    // XEP-0198 Stream Management
    private var serverSupportsSM: Bool = false
    private var smID: String?
    private var smInH: UInt32 = 0
    private var smOutH: UInt32 = 0
    private var unackedStanzas: [(h: UInt32, xml: String)] = []
    
#if DEBUG
    // MARK: - Testing Hooks
    var test_smID: String? { smID }
    var test_unackedStanzasCount: Int { unackedStanzas.count }
    var test_smInH: UInt32 { smInH }
    var test_smOutH: UInt32 { smOutH }
    
    func test_setSMState(id: String, inH: UInt32, outH: UInt32, unacked: [(UInt32, String)]) {
        self.smID = id
        self.smInH = inH
        self.smOutH = outH
        self.unackedStanzas = unacked
        self.phase = .active
    }
#endif

    // MARK: - Public State
    
    func getActiveContacts() -> [Contact] {
        return Array(contacts.values)
    }

    // MARK: - Init

    init() {
        let (cs, cc) = AsyncStream<ConnectionState>.makeStream()
        connectionStateStream = cs; _connCont = cc
        connectionState = cs
    }

    // MARK: - Public API

    /// Connects to `host:port`, authenticates with SASL PLAIN, and enters active state.
    func connect(jid: String, password: String, host: String? = nil, port: Int = 5222) async throws {
        guard phase == .disconnected else { return }

        self.password = password
        let (local, dom) = parseJID(jid)
        self.myBareJID = "\(local)@\(dom)"
        self.domain    = dom
        let connectHost = host ?? dom

        emit(.connecting)

        try openConnection(host: connectHost, port: port)
    }

    func disconnect() {
        guard phase != .disconnected else { return }
        if phase == .active {
            send("<presence type='unavailable'/>")
        }
        send("</stream:stream>")
        
        // Clear SM state on explicit logout
        smID = nil
        smInH = 0
        smOutH = 0
        unackedStanzas.removeAll()
        
        tearDown()
        emit(.disconnected)
    }

    /// Creates and sends a `<message>` stanza. Returns the domain `Message` immediately.
    @discardableResult
    func sendMessage(to recipientJID: String, body: String) throws -> Message {
        guard phase == .active else { throw XMPPError.notConnected }
        let msgID = UUID().uuidString
        let bareTo = bareJID(recipientJID)
        
        var bodyXML = "<body>\(escapeXML(body))</body>"
        var e2eeXML = ""
        
        if let pubKey = contacts[bareTo]?.publicKey,
           let payload = body.data(using: .utf8),
           let (ciphertext, _) = try? CryptoService.shared.encrypt(payload: payload, recipientPublicKeyBase64: pubKey) {
            bodyXML = "<body>E2EE Message. This client doesn't support decryption.</body>"
            e2eeXML = "<e2ee xmlns=\"urn:xmppdemo:e2ee\">\(ciphertext)</e2ee>"
        }
        
        let xml = """
        <message type="chat" to="\(recipientJID)" id="\(msgID)" xml:lang="en">\
        \(bodyXML)\
        \(e2eeXML)\
        <active xmlns="http://jabber.org/protocol/chatstates"/>\
        <request xmlns="urn:xmpp:receipts"/>\
        </message>
        """
        send(xml)
        return Message(
            id: msgID, fromJID: myBareJID, toJID: bareJID(recipientJID),
            body: body, timestamp: .now, deliveryStatus: .sent, isOutgoing: true
        )
    }

    func requestUploadSlot(filename: String, size: Int, mimeType: String) async throws -> (putURL: URL, getURL: URL) {
        guard phase == .active else { throw XMPPError.disconnected }

        let id = UUID().uuidString
        let uploadDomain = "upload.\(domain)"
        
        let requestXML = """
        <iq type='get' to='\(escapeXML(uploadDomain))' id='\(id)'>\
        <request xmlns='urn:xmpp:http:upload:0' filename='\(escapeXML(filename))' size='\(size)' content-type='\(escapeXML(mimeType))'/>\
        </iq>
        """
        
        send(requestXML)
        
        let response = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<XMPPElement, Error>) in
            self.iqCallbacks[id] = cont
            
            // Timeout after 15s
            Task {
                try? await Task.sleep(for: .seconds(15))
                await self.timeoutPing(id: id)
            }
        }
        
        if response.attributes["type"] == "error" {
            throw XMPPError.connectionFailed("Server rejected upload slot request")
        }
        
        let slot = try HTTPUploadSlot(response: response)
        return (slot.putURL, slot.getURL)
    }

    func sendChatState(_ state: ChatState, to recipientJID: String) {
        guard phase == .active else { return }
        send("""
        <message type="chat" to="\(recipientJID)">\
        <\(state.rawValue) xmlns="http://jabber.org/protocol/chatstates"/>\
        </message>
        """)
    }

    func sendReceipt(to recipientJID: String, originalID: String) {
        guard phase == .active else { return }
        send("""
        <message to="\(recipientJID)">\
        <received xmlns="urn:xmpp:receipts" id="\(originalID)"/>\
        </message>
        """)
    }

    func sendPresence(show: String? = nil, statusText: String? = nil) {
        guard phase == .active else { return }
        var xml = "<presence>"
        if let show { xml += "<show>\(show)</show>" }
        if let s = statusText { xml += "<status>\(escapeXML(s))</status>" }
        
        // Append E2EE Public Key
        if let pubKey = try? CryptoService.shared.getMyPublicKeyBase64() {
            xml += "<e2ee-pubkey xmlns=\"urn:xmppdemo:e2ee\">\(pubKey)</e2ee-pubkey>"
        }
        
        xml += "</presence>"
        send(xml)
    }

    func requestRoster() {
        guard phase == .active else { return }
        let id = UUID().uuidString
        send("<iq type=\"get\" id=\"\(id)\"><query xmlns=\"jabber:iq:roster\"/></iq>")
    }

    func addContact(jid: String) {
        guard phase == .active else { return }
        let bare = bareJID(jid)
        pendingSubscriptions.insert(bare)
        send("<presence type=\"subscribe\" to=\"\(escapeXML(bare))\"/>")
    }

    // MARK: - TCP Connection

    private func openConnection(host: String, port: Int) throws {
        var readRef:  Unmanaged<CFReadStream>?
        var writeRef: Unmanaged<CFWriteStream>?

        CFStreamCreatePairWithSocketToHost(kCFAllocatorDefault, host as CFString, UInt32(port), &readRef, &writeRef)

        guard let r = readRef?.takeRetainedValue(), let w = writeRef?.takeRetainedValue() else {
            throw XMPPError.connectionFailed("CFStream creation failed")
        }

        let inputStream  = r as InputStream
        let outputStream = w as OutputStream

        resetParser()

        let bridge = StreamBridge()
        bridge.onData  = { [weak self] data  in Task { await self?.receivedData(data)   } }
        bridge.onError = { [weak self] error in Task { await self?.streamError(error)   } }
        bridge.onEnd   = { [weak self]       in Task { await self?.streamDisconnected() } }
        // Only open the XMPP stream once the output socket is actually ready.
        // Writing before openCompleted fires causes a silent failure and the
        // server never receives <stream:stream>, leaving us stuck at .connecting.
        bridge.onOpen  = { [weak self] in Task { await self?.openStream() } }

        let w2 = StreamWorker(input: inputStream, output: outputStream, bridge: bridge)
        self.worker = w2

        phase = .tcpConnected
        // Do NOT call openStream() here — it runs after onOpen fires.
    }

    // MARK: - Stream Open

    private func openStream() {
        send("""
        <?xml version="1.0"?>\
        <stream:stream to="\(domain)" \
        xmlns="jabber:client" \
        xmlns:stream="http://etherx.jabber.org/streams" \
        version="1.0">
        """)
    }

    // MARK: - Incoming Data

    func receivedData(_ data: Data) {
        parser.receive(data: data)
    }

    func streamError(_ error: Error?) {
        emit(.failed(reason: error?.localizedDescription ?? "Stream error"))
        tearDown()
    }

    func streamDisconnected() {
        guard phase != .disconnected else { return }
        tearDown()
        emit(.disconnected)
    }

    // MARK: - Parser Wiring

    private func resetParser() {
        parser = XMPPStreamParser()
        parser.onStreamOpened = { [weak self] id, from in
            Task { await self?.streamOpened(id: id, from: from) }
        }
        parser.onStanza = { [weak self] element in
            Task { await self?.handleStanza(XMPPStanza.parse(element)) }
        }
        parser.onStreamClosed = { [weak self] in
            Task { await self?.streamDisconnected() }
        }
    }

    // MARK: - Stream Opened

    private func streamOpened(id _: String, from _: String) {
        // Called after every new stream:stream opening (post-TLS, post-SASL)
    }

    // MARK: - Stanza Router

    private func handleStanza(_ stanza: XMPPStanza) {
        // XEP-0198: Increment incoming stanza count for ackable stanzas
        switch stanza {
        case .message, .presence, .iq, .chatState:
            if smID != nil { smInH &+= 1 }
        default:
            break
        }

        switch stanza {

        case .streamFeatures(let el):
            negotiateFeatures(el)

        case .proceed:
            upgradeTLS()

        case .saslSuccess:
            // Reset parser and re-open stream after SASL
            phase = .saslSucceeded
            resetParser()
            openStream()

        case .saslFailure(let condition):
            emit(.failed(reason: "Auth failed: \(condition)"))
            tearDown()

        case .saslChallenge:
            break  // PLAIN mechanism doesn't use challenges

        case .message(let from, _, let id, let rawBody, let requestReceipt, let receiptID, let e2eeCiphertext):
            // 1. Handle incoming delivery receipts
            if let receiptID {
                print("[DEBUG] Received delivery receipt for msg: \(receiptID)")
                NotificationCenter.default.post(name: .xmppMessageDelivered, object: nil, userInfo: ["messageID": receiptID])
            }
            
            // 2. Decrypt E2EE Payload if present
            var body = rawBody
            let bareFrom = bareJID(from)
            if let ciphertext = e2eeCiphertext, let senderPubKey = contacts[bareFrom]?.publicKey {
                if let decryptedData = try? CryptoService.shared.decrypt(combinedBase64: ciphertext, senderPublicKeyBase64: senderPubKey),
                   let decryptedString = String(data: decryptedData, encoding: .utf8) {
                    body = decryptedString
                } else {
                    body = "⚠️ [Encrypted Message - Decryption Failed]"
                }
            } else if e2eeCiphertext != nil {
                body = "⚠️ [Encrypted Message - Unknown Public Key]"
            }
            
            // 3. Ignore messages with no body (they are just acks or chat states)
            guard !body.isEmpty else { return }
            print("[DEBUG] XMPPManager parsed message stanza from \(from): \(body)")
            
            // 4. Send back a receipt if requested (XEP-0184)
            if requestReceipt {
                sendReceipt(to: from, originalID: id)
            }
            
            let msg = Message(
                id: id, fromJID: bareFrom, toJID: myBareJID,
                body: body, timestamp: .now, deliveryStatus: .delivered, isOutgoing: false
            )
            NotificationCenter.default.post(name: .xmppInboundMessage, object: nil, userInfo: ["message": msg])

        case .presence(let from, let show, let statusText, let type, let e2eePubKey):
            handlePresence(from: from, show: show, statusText: statusText, type: type, e2eePubKey: e2eePubKey)

        case .iq(let id, let type, let element):
            handleIQ(id: id, type: type, element: element)

        case .chatState(let from, let state):
            NotificationCenter.default.post(name: .xmppChatState, object: nil, userInfo: ["from": bareJID(from), "state": state])

        case .streamError(let condition):
            emit(.failed(reason: "Stream error: \(condition)"))
            tearDown()

        case .smEnabled(let id, _):
            self.smID = id
            self.phase = .active
            onSessionReady()
            
        case .smResumed(_, let h):
            handleSMAck(h)
            self.phase = .active
            onSessionReady()
            
            // Resend unacked stanzas
            for unacked in unackedStanzas {
                worker?.write(unacked.xml)
            }
            
        case .smFailed:
            self.smID = nil
            self.unackedStanzas.removeAll()
            
            if phase == .smResuming {
                // Resume failed, fallback to normal binding
                bindResource()
            }
            
        case .smAckRequest:
            send("<a xmlns='urn:xmpp:sm:3' h='\(smInH)'/>")
            
        case .smAck(let h):
            handleSMAck(h)

        case .unknown:
            break
        }
    }

    // MARK: - Feature Negotiation

    private func negotiateFeatures(_ features: XMPPElement) {
        switch phase {

        case .tcpConnected:
            // ALWAYS bypass STARTTLS because iOS 18 completely rejects self-signed local certificates.
            sendSASLAuth()

        case .tlsNegotiated, .saslSucceeded:
            serverSupportsSM = features.hasChild(named: "sm")
            
            if features.hasChild(named: "mechanisms") {
                sendSASLAuth()
            } else if serverSupportsSM, let smID = smID {
                // If we have an existing session, resume it instead of binding
                phase = .smResuming
                send("<resume xmlns='urn:xmpp:sm:3' h='\(smInH)' previd='\(escapeXML(smID))'/>")
            } else if features.hasChild(named: "bind") {
                bindResource()
            }

        default:
            break
        }
    }

    // MARK: - TLS Upgrade

    private func upgradeTLS() {
        worker?.upgradeTLS()
        phase = .tlsNegotiated
        resetParser()
        openStream()
    }

    // MARK: - SASL PLAIN

    private func sendSASLAuth() {
        phase = .saslSent
        let local = myBareJID.components(separatedBy: "@").first ?? myBareJID
        // PLAIN: \0localpart\0password
        let raw = "\0\(local)\0\(password)"
        let encoded = Data(raw.utf8).base64EncodedString()
        send("""
        <auth xmlns="urn:ietf:params:xml:ns:xmpp-sasl" mechanism="PLAIN">\(encoded)</auth>
        """)
    }

    // MARK: - Resource Binding

    private func bindResource() {
        phase = .binding
        let id = UUID().uuidString
        send("""
        <iq type="set" id="\(id)">\
        <bind xmlns="urn:ietf:params:xml:ns:xmpp-bind">\
        <resource>\(resource)</resource>\
        </bind>\
        </iq>
        """)
    }

    // MARK: - IQ Handling

    private func handleIQ(id: String, type: String, element: XMPPElement) {
        // Resource binding result
        if phase == .binding,
           let bind = element.child(named: "bind"),
           let jidEl = bind.child(named: "jid") {
            myFullJID = jidEl.text
            
            if serverSupportsSM {
                phase = .smEnabling
                send("<enable xmlns='urn:xmpp:sm:3' resume='true'/>")
            } else {
                phase = .active
                onSessionReady()
            }
            return
        }

        // Incoming Ping (XEP-0199)
        if type == "get", element.hasChild(named: "ping") {
            // Respond with a result
            send("<iq type=\"result\" to=\"\(escapeXML(myBareJID.components(separatedBy: "@").last ?? domain))\" id=\"\(id)\"/>")
            return
        }

        // Roster result
        if let query = element.child(named: "query"),
           query.attributes["xmlns"] == "jabber:iq:roster" {
            let updated = query.children(named: "item").compactMap { item -> Contact? in
                guard let jid = item.attributes["jid"] else { return nil }
                let currentPresence = self.contacts[jid]?.presenceStatus ?? .offline
                let currentPubKey = self.contacts[jid]?.publicKey
                return Contact(jid: jid, name: item.attributes["name"] ?? "", presenceStatus: currentPresence, publicKey: currentPubKey)
            }
            updated.forEach { contacts[$0.jid] = $0 }
            let contactsArray = Array(contacts.values)
            NotificationCenter.default.post(name: .xmppRosterUpdate, object: nil, userInfo: ["contacts": contactsArray])
            return
        }

        // Pending continuation (request/response pattern)
        if let cont = iqCallbacks.removeValue(forKey: id) {
            type == "result"
                ? cont.resume(returning: element)
                : cont.resume(throwing: XMPPError.iqError)
        }
    }

    // MARK: - Presence Handling

    private func handlePresence(from: String, show: String?, statusText: String?, type: String?, e2eePubKey: String?) {
        let bare = bareJID(from)
        guard bare != myBareJID else { return }

        // Save public key if provided, regardless of presence type
        if let pk = e2eePubKey {
            if contacts[bare] == nil {
                contacts[bare] = Contact(jid: bare, name: bare, presenceStatus: .offline, publicKey: pk)
            } else {
                contacts[bare]?.publicKey = pk
            }
        }

        if type == "subscribe" {
            // Auto-accept
            send("<presence type=\"subscribed\" to=\"\(escapeXML(bare))\"/>")
            
            // Subscribe back for two-way presence if we haven't already
            if !pendingSubscriptions.contains(bare) {
                pendingSubscriptions.insert(bare)
                send("<presence type=\"subscribe\" to=\"\(escapeXML(bare))\"/>")
            }
            
            sendPresence() // Force broadcast
            return
        }

        if type == "subscribed" || type == "unsubscribed" {
            sendPresence() // Force broadcast
            return
        }

        let status = PresenceStatus.from(xmppShow: show, type: type)
        if contacts[bare] == nil {
            contacts[bare] = Contact(jid: bare, name: bare, presenceStatus: status, publicKey: e2eePubKey)
        } else {
            contacts[bare]?.presenceStatus = status
        }
        
        // Pass publicKey inside userInfo so ConversationListViewModel can update RosterStore
        var userInfo: [AnyHashable: Any] = ["jid": bare, "status": status]
        if let pk = e2eePubKey { userInfo["publicKey"] = pk }
        
        NotificationCenter.default.post(name: .xmppPresenceUpdate, object: nil, userInfo: userInfo)
        let contactsArray = Array(contacts.values)
        NotificationCenter.default.post(name: .xmppRosterUpdate, object: nil, userInfo: ["contacts": contactsArray])
    }

    // MARK: - Utilities

    private func startPingTimer() {
        pingTask?.cancel()
        pingTask = Task { [weak self] in
            await self?.pingLoop()
        }
    }

    private func pingLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(30))
            guard !Task.isCancelled else { break }
            
            let id = UUID().uuidString
            send("<iq type=\"get\" id=\"\(id)\"><ping xmlns=\"urn:xmpp:ping\"/></iq>")
            
            do {
                _ = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<XMPPElement, Error>) in
                    self.iqCallbacks[id] = cont
                    
                    Task {
                        try? await Task.sleep(for: .seconds(10))
                        await self.timeoutPing(id: id)
                    }
                }
            } catch {
                print("[XMPP] Ping failed or timed out: \(error). Disconnecting.")
                streamDisconnected()
                break
            }
        }
    }

    private func timeoutPing(id: String) {
        if let cont = iqCallbacks.removeValue(forKey: id) {
            cont.resume(throwing: XMPPError.timeout)
        }
    }

    private func emit(_ state: ConnectionState) {
        _connCont.yield(state)
    }

    // MARK: - Stream Management Helpers
    
    private func onSessionReady() {
        emit(.connected)
        sendPresence()
        requestRoster()
        startPingTimer()
    }
    
    private func handleSMAck(_ h: UInt32) {
        unackedStanzas.removeAll { $0.h <= h }
    }

    // MARK: - Sending

    @discardableResult
    private func send(_ xml: String) -> Bool {
        let success = worker?.write(xml) ?? false
        
        // Track unacknowledged stanzas if Stream Management is active
        if success, phase == .active, smID != nil {
            let isAckable = xml.hasPrefix("<message") || xml.hasPrefix("<iq") || xml.hasPrefix("<presence")
            if isAckable {
                smOutH &+= 1
                unackedStanzas.append((h: smOutH, xml: xml))
                
                // Request ack
                worker?.write("<r xmlns='urn:xmpp:sm:3'/>")
            }
        }
        
        return success
    }

    private func tearDown() {
        phase = .disconnected
        pingTask?.cancel()
        pingTask = nil
        worker?.close()
        worker = nil
        iqCallbacks.values.forEach { $0.resume(throwing: XMPPError.disconnected) }
        iqCallbacks.removeAll()
        contacts.removeAll()
    }

    private func bareJID(_ jid: String) -> String {
        jid.components(separatedBy: "/").first ?? jid
    }

    private func parseJID(_ jid: String) -> (local: String, domain: String) {
        let parts = jid.components(separatedBy: "@")
        let local  = parts.first ?? ""
        let domain = parts.count > 1 ? parts[1].components(separatedBy: "/").first ?? parts[1] : ""
        return (local, domain)
    }

    private func escapeXML(_ str: String) -> String {
        str
            .replacingOccurrences(of: "&",  with: "&amp;")
            .replacingOccurrences(of: "<",  with: "&lt;")
            .replacingOccurrences(of: ">",  with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'",  with: "&apos;")
    }
}

// MARK: - XMPPError

nonisolated enum XMPPError: LocalizedError {
    case invalidJID
    case notConnected
    case disconnected
    case connectionFailed(String)
    case authenticationFailed(String)
    case iqError
    case timeout

    var errorDescription: String? {
        switch self {
        case .invalidJID:                  return "Invalid JID — expected user@domain"
        case .notConnected:                return "Not connected to server"
        case .disconnected:                return "Disconnected from server"
        case .connectionFailed(let r):     return "Connection failed: \(r)"
        case .authenticationFailed(let r): return "Authentication failed: \(r)"
        case .iqError:                     return "Server returned an IQ error"
        case .timeout:                     return "Operation timed out"
        }
    }
}

// MARK: - StreamWorker
//
// Owns the InputStream/OutputStream pair and runs a dedicated RunLoop thread.
// @unchecked Sendable because stream access is confined to that thread.

nonisolated final class StreamWorker: @unchecked Sendable {

    private let inputStream:  InputStream
    private let outputStream: OutputStream
    private let bridge: StreamBridge
    private let thread: Thread

    init(input: InputStream, output: OutputStream, bridge: StreamBridge) {
        self.inputStream  = input
        self.outputStream = output
        self.bridge = bridge

        // Capture local refs to avoid actor-isolation issues inside the Thread closure
        nonisolated(unsafe) let ins = input
        nonisolated(unsafe) let outs = output
        let b = bridge

        thread = Thread {
            ins.delegate  = b
            outs.delegate = b
            ins.schedule(in:  .current, forMode: .common)
            outs.schedule(in: .current, forMode: .common)
            ins.open()
            outs.open()
            RunLoop.current.run()  // blocks until thread is cancelled
        }
        thread.name = "com.xmppdemo.stream-worker"
        thread.qualityOfService = .userInitiated
        thread.start()
    }

    @discardableResult
    func write(_ xml: String) -> Bool {
        guard let data = xml.data(using: .utf8) else { return false }
        var written = 0
        data.withUnsafeBytes { ptr in
            guard let base = ptr.bindMemory(to: UInt8.self).baseAddress else { return }
            while written < data.count {
                let n = outputStream.write(base + written, maxLength: data.count - written)
                guard n > 0 else { return }
                written += n
            }
        }
        return written == data.count
    }

    func upgradeTLS() {
        let settings: [CFString: Any] = [kCFStreamSSLValidatesCertificateChain: kCFBooleanTrue as Any]
        let sslKey = CFStreamPropertyKey(rawValue: kCFStreamPropertySSLSettings)
        CFReadStreamSetProperty(inputStream, sslKey, settings as CFDictionary)
        CFWriteStreamSetProperty(outputStream, sslKey, settings as CFDictionary)
        inputStream.setProperty(
            StreamSocketSecurityLevel.negotiatedSSL.rawValue,
            forKey: .socketSecurityLevelKey
        )
        outputStream.setProperty(
            StreamSocketSecurityLevel.negotiatedSSL.rawValue,
            forKey: .socketSecurityLevelKey
        )
    }

    func close() {
        thread.cancel()
        inputStream.close()
        outputStream.close()
    }
}

// MARK: - StreamBridge
//
// NSObject StreamDelegate that bridges RunLoop callbacks → async Tasks.
// @unchecked Sendable: closures are set once before start, thread-safe by usage.

nonisolated final class StreamBridge: NSObject, StreamDelegate, @unchecked Sendable {
    var onData:  ((Data) -> Void)?
    var onError: ((Error?) -> Void)?
    var onEnd:   (() -> Void)?
    /// Fired once when the output stream is ready to accept writes.
    var onOpen:  (() -> Void)?

    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        switch eventCode {
        case .openCompleted:
            // Only notify when the output stream opens — that's when we can write.
            if aStream is OutputStream {
                print("[XMPP] Output stream openCompleted — sending <stream:stream>")
                onOpen?()
            }

        case .hasBytesAvailable:
            guard let input = aStream as? InputStream else { return }
            var buf = [UInt8](repeating: 0, count: 8_192)
            let n = input.read(&buf, maxLength: buf.count)
            if n > 0 { onData?(Data(buf[..<n])) }

        case .errorOccurred:
            onError?(aStream.streamError)

        case .endEncountered:
            onEnd?()

        default:
            break
        }
    }
}

extension Notification.Name {
    static let xmppInboundMessage = Notification.Name("xmppInboundMessage")
    static let xmppOutboundMessage = Notification.Name("xmppOutboundMessage")
    static let xmppRosterUpdate = Notification.Name("xmppRosterUpdate")
    static let xmppPresenceUpdate = Notification.Name("xmppPresenceUpdate")
    static let xmppChatState = Notification.Name("xmppChatState")
    static let didInsertMessage = Notification.Name("didInsertMessage")
    static let xmppMessageDelivered = Notification.Name("xmppMessageDelivered")
}
