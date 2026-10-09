# XMPP Real-Time Messaging Client

A high-performance, offline-first iOS XMPP chat client built from scratch using **Swift Concurrency**, **SwiftUI**, and **SwiftData**. Features a custom TCP socket layer bypassing legacy dependencies.

This project demonstrates a production-ready real-time messaging architecture, completely bypassing heavy legacy Objective-C dependencies like `XMPPFramework`. It features a custom `NWConnection` socket layer, a lightweight raw XML stream parser, end-to-end message encryption, and an offline-first sync engine.

---

## 🚀 Key Features

* **Custom XMPP Engine:** Built purely in Swift using `Network.framework` (TCP sockets) and custom `XMLParser` handler. Manages full XMPP handshake including TLS upgrades (`STARTTLS`), SASL authentication (Plain), and resource binding.
* **End-to-End Encryption (E2EE):** Zero-trust message encryption using Apple's **CryptoKit**. P-256 Elliptic Curve Diffie-Hellman (ECDH) key agreement, HKDF-SHA256 key derivation, and AES-GCM-256 payload sealing with dynamic public key exchange via presence stanzas (`<e2ee-pubkey>`).
* **Secure Enclave Storage:** Hardware-backed private key generation (`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`) with Keychain fallback for iOS Simulators.
* **Offline-First Architecture:** Powered by **SwiftData**. Messages and roster contacts are persisted locally *before* transmission, ensuring zero data loss during network disconnects. The UI reads exclusively from the local cache.
* **Real-Time Presence & Status:** Live bidirectional presence tracking (`Available`, `Away`, `Offline`) with automated roster subscription handling and typing indicators.
* **Media & Image Sharing:** Built-in XEP-0363 HTTP File Upload support for sending images over TLS with async upload progress indicators.
* **Modern Concurrency & Architecture:** Built with Swift Concurrency (`async/await`, `Task`, `Sendable`, `@Observable`), decoupled clean MVVM pattern, and dependency injection.

---

## 🛠 Tech Stack & Standards

- **UI & UX:** SwiftUI (iOS 17+), custom dark-mode glassmorphic design system.
- **Concurrency:** Swift 5.10 / 6 ready Concurrency (`async/await`, `Task`, `MainActor`, `Sendable`).
- **Cryptography & Security:** `CryptoKit`, `Security.framework` (Keychain), Secure Enclave.
- **Persistence:** `SwiftData` (`ModelContainer`, `@Model`).
- **Networking:** `Network.framework` (`NWConnection`), custom XML stream parser.
- **XMPP & XEP Specifications:**
  - **RFC 6120:** XMPP Core (Stream management, TLS, SASL)
  - **RFC 6121:** XMPP Instant Messaging & Presence (Roster management)
  - **XEP-0363:** HTTP File Upload (Media attachment delivery)
  - **E2EE Extension:** Custom `<e2ee-pubkey>` and `<e2ee>` stanza payload extension.

---

## 📱 Screenshots
<img src="https://github.com/user-attachments/assets/eeb38d83-470b-40bb-b6ec-94c4b088201c" width="256" height="556" />
<img src="https://github.com/user-attachments/assets/12d76824-5a08-4111-a9cb-729420f41163" width="256" height="556" />
<img src="https://github.com/user-attachments/assets/4f50ad68-1079-4fcc-a96f-463dcb1af3bc" width="256" height="556" />

---

## 🧠 Architecture Highlights

### 1. The Real-Time Engine (`XMPPManager`)
Maintains a persistent background TCP socket via `Network.framework`. Incoming XML fragments are streamed through an event-driven parser. When `<iq>`, `<presence>`, or `<message>` stanzas arrive, they are parsed into strongly-typed Swift models and handled asynchronously without blocking the UI.

### 2. End-to-End Encryption Engine (`CryptoService`)
Upon authenticating, the client advertises its ECDH P-256 public key over XMPP presence. When sending a chat message, `CryptoService` derives an ephemeral symmetric key via HKDF SHA-256 from the recipient's public key and encrypts the plaintext payload using AES-GCM-256.

### 3. Data Synchronization (`MessageStore` & `RosterStore`)
Local-first strategy. Messages are immediately saved to SwiftData and rendered in the view, while background tasks manage XMPP network delivery. If network connectivity drops, outbound updates queue gracefully.

---

## 🧪 Testing & Quality Assurance

The codebase includes an automated unit test suite covering critical layers:
- **`CryptoServiceTests`:** Validates ECDH key agreement, public key derivation, and AES-GCM encryption/decryption round-trips.
- **`XMPPStanzaTests`:** Verifies XML serialization/parsing for core stanzas, presence updates, and `<e2ee>` encrypted payloads.
- **`XMPPStreamParserTests`:** Validates chunked TCP data buffering and XML stream parsing edge cases.
- **`AuthViewModelTests` & `ConversationListViewModelTests`:** Tests authentication validation and view model state handling.
- **`MessageStoreTests`:** Tests SwiftData query filtering and message history persistence.

---

## 🚀 Getting Started

1. **Clone the repository:**
   ```bash
   git clone https://github.com/username/XMPPDemo.git
   cd XMPPDemo
   ```

2. **Run a local XMPP Server (`ejabberd`):**
   ```bash
   brew install ejabberd
   ejabberdctl start
   ejabberdctl register alice localhost password123
   ejabberdctl register bob localhost password123
   ```

3. **Build & Run:** Open `XMPPDemo.xcodeproj` in Xcode 15+ and run on two iOS 17+ Simulators.

4. **Login & Chat:** Sign in as `alice@localhost` on Simulator 1 and `bob@localhost` on Simulator 2 to experience real-time messaging, presence sync, and E2EE encryption.

### Local Image Upload Setup (XEP-0363)

To test HTTP image uploads locally with `ejabberd`:

```bash
openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout /opt/homebrew/etc/ejabberd/localhost.pem \
  -out /opt/homebrew/etc/ejabberd/localhost.pem \
  -days 3650 -subj "/CN=localhost" \
  -addext "subjectAltName=DNS:localhost,DNS:upload.localhost,IP:127.0.0.1,IP:::1"
```

Add the certificate path to your `ejabberd.yml`:
```yaml
certfiles:
  - /opt/homebrew/etc/ejabberd/localhost.pem
```

---

## 📝 License
This project is created for demonstration and portfolio purposes.
