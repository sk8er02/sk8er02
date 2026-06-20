import SwiftUI
import SwiftData

@main
struct PancreasGuardWatchApp: App {
    @State private var connectivityService = WatchConnectivityService()

    var body: some Scene {
        WindowGroup {
            WatchDashboardView()
                .environment(connectivityService)
        }
        .modelContainer(for: [
            SymptomEntry.self,
            HealthSnapshot.self
        ])
    }
}
