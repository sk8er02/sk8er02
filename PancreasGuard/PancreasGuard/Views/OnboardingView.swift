import SwiftUI

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @Environment(HealthKitManager.self) private var healthKit
    @State private var currentPage = 0
    @State private var disclaimerAccepted = false

    var body: some View {
        NavigationStack {
            TabView(selection: $currentPage) {
                welcomePage.tag(0)
                disclaimerPage.tag(1)
                healthKitPage.tag(2)
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))
        }
        .interactiveDismissDisabled()
    }

    private var welcomePage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "waveform.path.ecg.rectangle")
                .font(.system(size: 80))
                .foregroundStyle(.blue)

            Text("PancreasGuard")
                .font(.largeTitle.bold())

            Text("Monitor your health signals and track symptoms to help identify pancreatitis flare-ups early.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)

            Spacer()

            VStack(spacing: 12) {
                featureRow(icon: "heart.fill", color: .red, title: "Heart Rate & HRV", subtitle: "Continuous monitoring via Apple Watch")
                featureRow(icon: "thermometer.medium", color: .orange, title: "Temperature", subtitle: "Track deviations from your baseline")
                featureRow(icon: "pencil.and.list.clipboard", color: .blue, title: "Symptom Diary", subtitle: "Log pain, nausea, and digestive issues")
                featureRow(icon: "bell.badge.fill", color: .purple, title: "Smart Alerts", subtitle: "Multi-signal risk scoring")
            }
            .padding(.horizontal, 24)

            Spacer()

            Button("Continue") {
                withAnimation { currentPage = 1 }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.bottom, 32)
        }
    }

    private var disclaimerPage: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "exclamationmark.shield.fill")
                .font(.system(size: 60))
                .foregroundStyle(.orange)

            Text("Important Disclaimer")
                .font(.title.bold())

            ScrollView {
                Text("""
                PancreasGuard is a health companion tool designed to help you track symptoms and monitor biometric trends.

                **This app is NOT a medical device.** It cannot diagnose pancreatitis or any other medical condition.

                This app does NOT replace professional medical advice, diagnosis, or treatment. Always consult your healthcare provider for medical decisions.

                The risk scoring system is based on published research correlations but has not been clinically validated for individual diagnostic use.

                If you experience severe symptoms — intense abdominal pain, persistent vomiting, high fever, rapid heartbeat, or confusion — seek emergency medical care immediately. Do not rely on this app.

                All your health data stays on your device and is never transmitted to external servers.
                """)
                .font(.subheadline)
                .padding(.horizontal, 24)
            }
            .frame(maxHeight: 280)

            Toggle("I understand and accept", isOn: $disclaimerAccepted)
                .padding(.horizontal, 32)

            Button("Continue") {
                withAnimation { currentPage = 2 }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!disclaimerAccepted)
            .padding(.bottom, 32)
        }
    }

    private var healthKitPage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "heart.text.clipboard.fill")
                .font(.system(size: 60))
                .foregroundStyle(.pink)

            Text("Connect Apple Health")
                .font(.title.bold())

            Text("PancreasGuard reads your heart rate, HRV, temperature, blood oxygen, and activity data to establish baselines and detect changes.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)

            VStack(alignment: .leading, spacing: 8) {
                Text("We will request access to:")
                    .font(.headline)
                dataRow("Heart Rate")
                dataRow("Heart Rate Variability")
                dataRow("Blood Oxygen")
                dataRow("Wrist Temperature")
                dataRow("Step Count")
                dataRow("Respiratory Rate")
                dataRow("Resting Heart Rate")
            }
            .padding(.horizontal, 32)

            Spacer()

            Button("Grant Access & Get Started") {
                Task {
                    try? await healthKit.requestAuthorization()
                    UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                    isPresented = false
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.bottom, 32)
        }
    }

    private func featureRow(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 32)
            VStack(alignment: .leading) {
                Text(title).font(.subheadline.bold())
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private func dataRow(_ text: String) -> some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.caption)
            Text(text).font(.subheadline)
        }
    }
}
