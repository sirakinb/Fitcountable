import SwiftUI

@main
struct FitcountableApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .task {
                    await appState.refreshPremiumStatus()
                }
        }
    }
}
