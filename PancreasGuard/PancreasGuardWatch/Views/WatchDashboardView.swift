import SwiftUI
import HealthKit

struct WatchDashboardView: View {
    @State private var heartRate: Double?
    @State private var riskLevel: RiskLevel = .green
    @State private var showingQuickLog = false

    private let store = HKHealthStore()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    riskStatusView
                    heartRateView
                    quickLogButton
                }
                .padding(.horizontal)
            }
            .navigationTitle("PG")
            .sheet(isPresented: $showingQuickLog) {
                QuickLogView()
            }
            .task { await startMonitoring() }
        }
    }

    private var riskStatusView: some View {
        VStack(spacing: 4) {
            Circle()
                .fill(riskColor)
                .frame(width: 24, height: 24)
            Text(riskLevel.rawValue)
                .font(.caption.bold())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(riskColor.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var heartRateView: some View {
        HStack {
            Image(systemName: "heart.fill")
                .foregroundStyle(.red)
            if let hr = heartRate {
                Text("\(Int(hr))")
                    .font(.title2.bold().monospacedDigit())
                Text("bpm")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("--")
                    .font(.title2.bold())
            }
            Spacer()
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var quickLogButton: some View {
        Button {
            showingQuickLog = true
        } label: {
            Label("Log Symptoms", systemImage: "plus.circle.fill")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
    }

    private var riskColor: Color {
        switch riskLevel {
        case .green: return .green
        case .yellow: return .yellow
        case .orange: return .orange
        case .red: return .red
        }
    }

    private func startMonitoring() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        try? await store.requestAuthorization(toShare: [], read: [heartRateType])

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKAnchoredObjectQuery(
            type: heartRateType,
            predicate: nil,
            anchor: nil,
            limit: 1
        ) { _, samples, _, _, _ in
            updateHeartRate(from: samples)
        }

        query.updateHandler = { _, samples, _, _, _ in
            updateHeartRate(from: samples)
        }

        store.execute(query)
    }

    private func updateHeartRate(from samples: [HKSample]?) {
        guard let sample = samples?.first as? HKQuantitySample else { return }
        let unit = HKUnit.count().unitDivided(by: .minute())
        let value = sample.quantity.doubleValue(for: unit)
        Task { @MainActor in
            heartRate = value
            riskLevel = value > 100 ? .orange : .green
        }
    }
}
