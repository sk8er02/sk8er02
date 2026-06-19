import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(HealthKitManager.self) private var healthKit
    @Environment(AlertEngine.self) private var alertEngine
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SymptomEntry.timestamp, order: .reverse) private var symptoms: [SymptomEntry]
    @Query(sort: \FoodEntry.timestamp, order: .reverse) private var foodEntries: [FoodEntry]
    @State private var isRefreshing = false

    private var riskAssessment: RiskAssessment? { alertEngine.currentAssessment }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    riskStatusCard
                    vitalSignsGrid
                    recentSymptomsCard
                    quickActionsCard
                }
                .padding()
            }
            .navigationTitle("PancreasGuard")
            .refreshable { await refresh() }
            .task { await refresh() }
        }
    }

    // MARK: - Risk Status Card

    private var riskStatusCard: some View {
        VStack(spacing: 12) {
            HStack {
                Circle()
                    .fill(riskColor)
                    .frame(width: 16, height: 16)
                Text(riskAssessment?.level.rawValue ?? "Analyzing...")
                    .font(.headline)
                Spacer()
                Text(riskAssessment.map { "Score: \(Int($0.score * 100))%" } ?? "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let assessment = riskAssessment {
                Text(assessment.recommendation)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                let activeSignals = assessment.activeSignals.filter(\.isActive)
                if !activeSignals.isEmpty {
                    Divider()
                    ForEach(activeSignals) { signal in
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                                .font(.caption)
                            Text(signal.name)
                                .font(.caption.bold())
                            Text(signal.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                    }
                }
            }
        }
        .padding()
        .background(riskColor.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(riskColor.opacity(0.3), lineWidth: 1)
        )
    }

    private var riskColor: Color {
        switch riskAssessment?.level ?? .green {
        case .green: return .green
        case .yellow: return .yellow
        case .orange: return .orange
        case .red: return .red
        }
    }

    // MARK: - Vital Signs Grid

    private var vitalSignsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            vitalCard(
                title: "Heart Rate",
                value: healthKit.latestSnapshot?.heartRate.map { "\(Int($0))" } ?? "--",
                unit: "bpm",
                icon: "heart.fill",
                color: .red
            )
            vitalCard(
                title: "HRV",
                value: healthKit.latestSnapshot?.heartRateVariability.map { "\(Int($0))" } ?? "--",
                unit: "ms",
                icon: "waveform.path.ecg",
                color: .purple
            )
            vitalCard(
                title: "Blood Oxygen",
                value: healthKit.latestSnapshot?.bloodOxygen.map { "\(Int($0))" } ?? "--",
                unit: "%",
                icon: "lungs.fill",
                color: .blue
            )
            vitalCard(
                title: "Temperature",
                value: healthKit.latestSnapshot?.wristTemperature.map { String(format: "%+.1f", $0) } ?? "--",
                unit: "°C",
                icon: "thermometer.medium",
                color: .orange
            )
            vitalCard(
                title: "Steps",
                value: healthKit.latestSnapshot?.stepCount.map { "\($0)" } ?? "--",
                unit: "today",
                icon: "figure.walk",
                color: .green
            )
            vitalCard(
                title: "Resp. Rate",
                value: healthKit.latestSnapshot?.respiratoryRate.map { "\(Int($0))" } ?? "--",
                unit: "br/min",
                icon: "wind",
                color: .teal
            )
        }
    }

    private func vitalCard(title: String, value: String, unit: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.title2.bold().monospacedDigit())
                Text(unit)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Recent Symptoms

    private var recentSymptomsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent Symptoms")
                .font(.headline)

            if symptoms.isEmpty {
                Text("No symptoms logged yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                ForEach(symptoms.prefix(3)) { entry in
                    HStack {
                        painIndicator(level: entry.painLevel)
                        VStack(alignment: .leading) {
                            Text("Pain: \(entry.painLevel)/10 — \(entry.painLocation.rawValue)")
                                .font(.subheadline)
                            Text(entry.timestamp, style: .relative)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if entry.hasNausea {
                            Image(systemName: "stomach")
                                .foregroundStyle(.orange)
                                .font(.caption)
                        }
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func painIndicator(level: Int) -> some View {
        Circle()
            .fill(painColor(level: level))
            .frame(width: 12, height: 12)
    }

    private func painColor(level: Int) -> Color {
        switch level {
        case 0: return .green
        case 1...3: return .yellow
        case 4...6: return .orange
        case 7...10: return .red
        default: return .gray
        }
    }

    // MARK: - Quick Actions

    private var quickActionsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick Actions")
                .font(.headline)

            HStack(spacing: 12) {
                NavigationLink {
                    SymptomLogView()
                } label: {
                    Label("Log Symptoms", systemImage: "plus.circle.fill")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                NavigationLink {
                    ReportView()
                } label: {
                    Label("Doctor Report", systemImage: "doc.text.fill")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Refresh

    private func refresh() async {
        isRefreshing = true
        let snapshot = await healthKit.fetchLatestSnapshot()
        let recentSymptoms = symptoms.filter { $0.timestamp > Date().addingTimeInterval(-6 * 3600) }
        let recentFood = foodEntries.filter { $0.timestamp > Date().addingTimeInterval(-24 * 3600) }
        _ = alertEngine.evaluate(snapshot: snapshot, symptoms: recentSymptoms, food: recentFood)
        isRefreshing = false
    }
}
