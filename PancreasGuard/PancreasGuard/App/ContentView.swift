import SwiftUI

struct ContentView: View {
    @Environment(HealthKitManager.self) private var healthKit
    @State private var showingOnboarding = !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")

    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "heart.text.clipboard")
                }

            SymptomLogView()
                .tabItem {
                    Label("Log", systemImage: "plus.circle.fill")
                }

            FoodLogView()
                .tabItem {
                    Label("Food", systemImage: "fork.knife")
                }

            TrendsView()
                .tabItem {
                    Label("Trends", systemImage: "chart.xyaxis.line")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .tint(.blue)
        .sheet(isPresented: $showingOnboarding) {
            OnboardingView(isPresented: $showingOnboarding)
        }
    }
}
