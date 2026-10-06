import SwiftUI

/// Root routing view — switches between Login and Conversation List
/// based on `AppEnvironment.isLoggedIn`.
struct ContentView: View {
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        Group {
            if env.isLoggedIn {
                ConversationListView()
                    .transition(.asymmetric(
                        insertion: .push(from: .trailing),
                        removal: .push(from: .leading)
                    ))
            } else {
                LoginView()
                    .transition(.asymmetric(
                        insertion: .push(from: .leading),
                        removal: .push(from: .trailing)
                    ))
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: env.isLoggedIn)
    }
}

/// Alias kept for MyApp.swift
typealias RootView = ContentView

#Preview {
    ContentView()
        .environment(AppEnvironment.shared)
}
