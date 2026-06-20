import SwiftUI

struct SettingsView: View {
    @AppStorage("hrThreshold") private var hrThreshold: Double = 100
    @AppStorage("hrvDropPercent") private var hrvDropPercent: Double = 30
    @AppStorage("spo2Threshold") private var spo2Threshold: Double = 94
    @AppStorage("tempThreshold") private var tempThreshold: Double = 1.0
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true

    var body: some View {
        NavigationStack {
            Form {
                Section("Alert Thresholds") {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Heart Rate")
                            Spacer()
                            Text(">\(Int(hrThreshold)) bpm")
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $hrThreshold, in: 80...130, step: 5)
                    }

                    VStack(alignment: .leading) {
                        HStack {
                            Text("HRV Drop")
                            Spacer()
                            Text(">\(Int(hrvDropPercent))%")
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $hrvDropPercent, in: 10...60, step: 5)
                    }

                    VStack(alignment: .leading) {
                        HStack {
                            Text("Blood Oxygen")
                            Spacer()
                            Text("<\(Int(spo2Threshold))%")
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $spo2Threshold, in: 85...97, step: 1)
                    }

                    VStack(alignment: .leading) {
                        HStack {
                            Text("Temperature Rise")
                            Spacer()
                            Text("+\(String(format: "%.1f", tempThreshold))°C")
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $tempThreshold, in: 0.5...3.0, step: 0.1)
                    }
                }

                Section("Notifications") {
                    Toggle("Enable Alerts", isOn: $notificationsEnabled)
                }

                Section("Data") {
                    NavigationLink("Export All Data") {
                        ReportView()
                    }
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }

                    NavigationLink("Medical Disclaimer") {
                        ScrollView {
                            Text("""
                            PancreasGuard is a health companion tool designed to help you track symptoms and monitor biometric trends.

                            This app is NOT a medical device. It has not been evaluated or approved by the FDA or any regulatory body. It cannot diagnose pancreatitis or any other medical condition.

                            This app does NOT replace professional medical advice, diagnosis, or treatment. Always consult your healthcare provider for medical decisions.

                            The risk scoring system is based on published research correlations between biometric signals and pancreatitis, including:

                            • Heart rate elevation in pancreatitis (Nature Scientific Reports, 2024)
                            • HRV changes in pancreatic disease (NCT04400903 clinical trial)
                            • Systemic inflammatory response markers

                            However, this system has not been clinically validated for individual diagnostic use.

                            If you experience severe symptoms — intense abdominal pain, persistent vomiting, high fever, rapid heartbeat, or confusion — seek emergency medical care immediately.

                            All your health data stays on your device and is never transmitted to external servers.
                            """)
                            .padding()
                        }
                        .navigationTitle("Disclaimer")
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}
