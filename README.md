# XMPP Real-Time Messaging Client

A high-performance, native iOS XMPP chat client built from scratch using **SwiftUI**, **Modern Swift Concurrency (`async/await`)**, and **SwiftData**. 

This project demonstrates a production-ready real-time messaging architecture, completely bypassing heavy legacy Objective-C dependencies like `XMPPFramework`. It features a custom `NWConnection` socket layer, a lightweight raw XML stream parser, and an offline-first sync engine.

## 🚀 Key Features

* **Custom XMPP Engine:** Built purely in Swift using `Network.framework` (TCP sockets) and `XMLParser`. Handles the full XMPP handshake including TLS upgrades (`STARTTLS`), SASL authentication (Plain), and resource binding.
* **Offline-First Architecture:** Powered by **SwiftData**. Messages and roster contacts are persisted locally *before* transmission, ensuring zero data loss during network disconnects. The UI reads exclusively from the local cache.
* **Real-Time Presence:** Live bidirectional presence tracking (`Online`, `Offline`, `Away`) with typing indicators and auto-subscription handling.
* **Modern Concurrency:** Zero thread-blocking. Uses `Task`, `async/await`, and `async let` for concurrent stream reading and UI updates.
* **Clean Architecture:** Strict MVVM separation. Domain models are fully decoupled from the network and persistence layers. UI reacts instantly via `@Observable`.
* **Security First:** Enforces TLS encryption for all stream traffic prior to authentication. 

## 🛠 Tech Stack
- **UI:** SwiftUI (iOS 17+)
- **Concurrency:** Swift Concurrency (`async/await`, `TaskGroups`, `AsyncStream`)
- **Persistence:** SwiftData
- **Networking:** `Network.framework` (`NWConnection`), custom XML stream parsing
- **Backend Compatibility:** Fully tested against `ejabberd` (Erlang) and fully compliant with RFC 6120/6121.

## 📱 Screenshots
<img src="https://github.com/user-attachments/assets/eeb38d83-470b-40bb-b6ec-94c4b088201c" width="256" height="556" />
<img src="https://github.com/user-attachments/assets/eaa8f366-e97c-4b14-b297-21601897f82b" width="256" height="556" />
<img src="https://github.com/user-attachments/assets/4f50ad68-1079-4fcc-a96f-463dcb1af3bc" width="256" height="556" />

## 🧠 Architecture Highlights

### The Real-Time Layer (`XMPPManager`)
Instead of polling or relying on bloated libraries, the app maintains a persistent background TCP socket. Incoming XML fragments are streamed through a custom event-driven parser. This layer is entirely decoupled—when an `<iq>` or `<message>` stanza arrives, it is parsed into strongly-typed Swift structs and broadcast to the view models via `NotificationCenter`.

### Data Synchronization (`MessageStore` & `RosterStore`)
The app uses a local-first approach. When you send a message, it is instantly written to SwiftData and rendered in the UI, while a detached background task manages the actual XMPP network delivery. If the socket disconnects, the app gracefully queues changes for the next reconnection.

## 🚀 Getting Started

1. **Clone the repository.**
2. **Run a local XMPP Server:** You can easily run `ejabberd` locally via Homebrew:
   ```bash
   brew install ejabberd
   ejabberdctl start
   ejabberdctl register alice localhost password123
   ejabberdctl register bob localhost password123
   ```
3. **Build & Run:** Open `XMPPDemo.xcodeproj` in Xcode 15+ and run on the iOS 17 Simulator.
4. **Login:** Use `alice@localhost` and `bob@localhost` across two simulators to test real-time chat and presence.

## 📝 License
This project is for demonstration and portfolio purposes.
