import SwiftUI
import SwiftData

@main
struct PancreasGuardApp: App {
    @State private var healthKit = HealthKitManager()
    @State private var alertEngine = AlertEngine()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(healthKit)
                .environment(alertEngine)
        }
        .modelContainer(for: [
            SymptomEntry.self,
            FoodEntry.self,
            HealthSnapshot.self,
            FlareEvent.self
        ])
    }
}
