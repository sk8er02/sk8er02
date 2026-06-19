import SwiftUI
import Charts
import SwiftData

struct TrendsView: View {
    @Environment(HealthKitManager.self) private var healthKit
    @Query(sort: \SymptomEntry.timestamp, order: .reverse) private var symptoms: [SymptomEntry]
    @Query(sort: \FlareEvent.timestamp, order: .reverse) private var flares: [FlareEvent]

    @State private var heartRateData: [(Date, Double)] = []
    @State private var hrvData: [(Date, Double)] = []
    @State private var selectedTimeRange = 7

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    timeRangePicker

                    heartRateChart
                    hrvChart
                    symptomFrequencyChart
                    flareTimelineSection
                }
                .padding()
            }
            .navigationTitle("Trends")
            .task { await loadData() }
            .onChange(of: selectedTimeRange) {
                Task { await loadData() }
            }
        }
    }

    private var timeRangePicker: some View {
        Picker("Time Range", selection: $selectedTimeRange) {
            Text("7 Days").tag(7)
            Text("30 Days").tag(30)
            Text("90 Days").tag(90)
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Heart Rate Chart

    private var heartRateChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Heart Rate", systemImage: "heart.fill")
                .font(.headline)
                .foregroundStyle(.red)

            if heartRateData.isEmpty {
                Text("No heart rate data available")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 150, alignment: .center)
            } else {
                Chart {
                    ForEach(heartRateData, id: \.0) { date, value in
                        LineMark(x: .value("Time", date), y: .value("BPM", value))
                            .foregroundStyle(.red)
                    }
                    RuleMark(y: .value("Tachycardia", 100))
                        .foregroundStyle(.red.opacity(0.4))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                        .annotation(position: .top, alignment: .trailing) {
                            Text("100 bpm")
                                .font(.caption2)
                                .foregroundStyle(.red.opacity(0.6))
                        }
                }
                .frame(height: 180)
                .chartYScale(domain: 40...140)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - HRV Chart

    private var hrvChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Heart Rate Variability", systemImage: "waveform.path.ecg")
                .font(.headline)
                .foregroundStyle(.purple)

            if hrvData.isEmpty {
                Text("No HRV data available")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 150, alignment: .center)
            } else {
                Chart {
                    ForEach(hrvData, id: \.0) { date, value in
                        LineMark(x: .value("Time", date), y: .value("ms", value))
                            .foregroundStyle(.purple)
                    }
                }
                .frame(height: 180)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Symptom Frequency

    private var symptomFrequencyChart: some View {
        let cutoff = Calendar.current.date(byAdding: .day, value: -selectedTimeRange, to: Date())!
        let filteredSymptoms = symptoms.filter { $0.timestamp >= cutoff }
        let dailyCounts = Dictionary(grouping: filteredSymptoms) { entry in
            Calendar.current.startOfDay(for: entry.timestamp)
        }.mapValues(\.count)
        let sortedCounts = dailyCounts.sorted(by: { $0.key < $1.key })

        return VStack(alignment: .leading, spacing: 8) {
            Label("Symptom Frequency", systemImage: "calendar")
                .font(.headline)
                .foregroundStyle(.orange)

            if sortedCounts.isEmpty {
                Text("No symptoms logged in this period")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
            } else {
                Chart {
                    ForEach(sortedCounts, id: \.key) { date, count in
                        BarMark(x: .value("Day", date, unit: .day), y: .value("Count", count))
                            .foregroundStyle(.orange.gradient)
                    }
                }
                .frame(height: 120)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Flare Timeline

    private var flareTimelineSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Flare Events", systemImage: "flame.fill")
                .font(.headline)
                .foregroundStyle(.red)

            if flares.isEmpty {
                Text("No flare events recorded")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                ForEach(flares.prefix(5)) { flare in
                    HStack {
                        Circle()
                            .fill(flareColor(flare.peakRiskLevel))
                            .frame(width: 10, height: 10)
                        VStack(alignment: .leading) {
                            Text(flare.peakRiskLevel.rawValue)
                                .font(.subheadline.bold())
                            Text(flare.triggerSignals.joined(separator: ", "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(flare.startTimestamp, style: .date)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func flareColor(_ level: RiskLevel) -> Color {
        switch level {
        case .green: return .green
        case .yellow: return .yellow
        case .orange: return .orange
        case .red: return .red
        }
    }

    private func loadData() async {
        heartRateData = await healthKit.fetchHeartRateHistory(days: selectedTimeRange)
        hrvData = await healthKit.fetchHRVHistory(days: selectedTimeRange)
    }
}
