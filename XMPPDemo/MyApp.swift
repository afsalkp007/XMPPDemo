import SwiftUI

@main
struct MyApp: App {
    @State private var env = AppEnvironment.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(env)
                .preferredColorScheme(.dark)
        }
    }
}
