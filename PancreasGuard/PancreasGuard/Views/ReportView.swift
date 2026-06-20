import SwiftUI
import SwiftData

struct ReportView: View {
    @Environment(HealthKitManager.self) private var healthKit
    @Environment(AlertEngine.self) private var alertEngine
    @Query(sort: \SymptomEntry.timestamp, order: .reverse) private var symptoms: [SymptomEntry]
    @Query(sort: \FoodEntry.timestamp, order: .reverse) private var foodEntries: [FoodEntry]
    @Query(sort: \FlareEvent.timestamp, order: .reverse) private var flares: [FlareEvent]

    @State private var reportDays = 30
    @State private var generatedReport = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Report Period") {
                    Picker("Days", selection: $reportDays) {
                        Text("7 Days").tag(7)
                        Text("14 Days").tag(14)
                        Text("30 Days").tag(30)
                        Text("90 Days").tag(90)
                    }
                    .pickerStyle(.segmented)
                }

                Section("Summary") {
                    summaryRow("Total Symptom Entries", value: "\(filteredSymptoms.count)")
                    summaryRow("Days with Pain ≥ 5", value: "\(highPainDays)")
                    summaryRow("Flare Events", value: "\(filteredFlares.count)")
                    summaryRow("Alcohol Entries", value: "\(alcoholDays)")
                    summaryRow("Avg Heart Rate", value: healthKit.baselines.averageHeartRate > 0 ? "\(Int(healthKit.baselines.averageHeartRate)) bpm" : "N/A")
                    summaryRow("Avg HRV", value: healthKit.baselines.averageHRV > 0 ? "\(Int(healthKit.baselines.averageHRV)) ms" : "N/A")
                }

                Section("Symptom Pattern") {
                    if filteredSymptoms.isEmpty {
                        Text("No symptoms logged in this period.")
                            .foregroundStyle(.secondary)
                    } else {
                        let avgPain = filteredSymptoms.map(\.painLevel).reduce(0, +) / max(filteredSymptoms.count, 1)
                        summaryRow("Average Pain Level", value: "\(avgPain)/10")
                        summaryRow("Nausea Episodes", value: "\(filteredSymptoms.filter(\.hasNausea).count)")
                        summaryRow("Vomiting Episodes", value: "\(filteredSymptoms.filter(\.hasVomiting).count)")

                        let locationCounts = Dictionary(grouping: filteredSymptoms.filter { $0.painLocation != .none }, by: \.painLocation)
                        if let mostCommon = locationCounts.max(by: { $0.value.count < $1.value.count }) {
                            summaryRow("Most Common Location", value: mostCommon.key.rawValue)
                        }
                    }
                }

                Section {
                    Button(action: generateReport) {
                        Label("Generate Report Text", systemImage: "doc.text")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .listRowBackground(Color.clear)
                }

                if !generatedReport.isEmpty {
                    Section("Report") {
                        Text(generatedReport)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)

                        ShareLink(item: generatedReport) {
                            Label("Share Report", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .navigationTitle("Doctor Report")
        }
    }

    private var filteredSymptoms: [SymptomEntry] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -reportDays, to: Date())!
        return symptoms.filter { $0.timestamp >= cutoff }
    }

    private var filteredFlares: [FlareEvent] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -reportDays, to: Date())!
        return flares.filter { $0.startTimestamp >= cutoff }
    }

    private var highPainDays: Int {
        let days = Set(filteredSymptoms.filter { $0.painLevel >= 5 }.map {
            Calendar.current.startOfDay(for: $0.timestamp)
        })
        return days.count
    }

    private var alcoholDays: Int {
        let cutoff = Calendar.current.date(byAdding: .day, value: -reportDays, to: Date())!
        return foodEntries.filter { $0.timestamp >= cutoff && $0.containsAlcohol }.count
    }

    private func summaryRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.bold())
        }
    }

    private func generateReport() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium

        var report = """
        PANCREASGUARD HEALTH REPORT
        Generated: \(dateFormatter.string(from: Date()))
        Period: Last \(reportDays) days
        ========================================

        BIOMETRIC BASELINES (7-day average)
        - Heart Rate: \(Int(healthKit.baselines.averageHeartRate)) bpm
        - HRV (SDNN): \(Int(healthKit.baselines.averageHRV)) ms
        - Blood Oxygen: \(Int(healthKit.baselines.averageSpO2))%
        - Daily Steps: \(healthKit.baselines.averageDailySteps)

        SYMPTOM SUMMARY
        - Total entries: \(filteredSymptoms.count)
        - Days with pain ≥ 5/10: \(highPainDays)
        """

        if !filteredSymptoms.isEmpty {
            let avgPain = filteredSymptoms.map(\.painLevel).reduce(0, +) / filteredSymptoms.count
            report += """

            - Average pain: \(avgPain)/10
            - Nausea episodes: \(filteredSymptoms.filter(\.hasNausea).count)
            - Vomiting episodes: \(filteredSymptoms.filter(\.hasVomiting).count)
            """
        }

        report += """


        FLARE EVENTS: \(filteredFlares.count)
        """

        for flare in filteredFlares {
            report += "\n  - \(dateFormatter.string(from: flare.startTimestamp)): \(flare.peakRiskLevel.rawValue) [\(flare.triggerSignals.joined(separator: ", "))]"
        }

        report += """


        DIETARY NOTES
        - Alcohol entries: \(alcoholDays)

        ========================================
        DISCLAIMER: This report is generated by PancreasGuard,
        a health companion app. It is NOT a medical diagnosis.
        Data is based on Apple Watch sensors and user-reported
        symptoms. Please discuss with your healthcare provider.
        """

        generatedReport = report
    }
}
