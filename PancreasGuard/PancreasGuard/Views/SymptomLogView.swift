import SwiftUI
import SwiftData

struct SymptomLogView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(HealthKitManager.self) private var healthKit
    @Query(sort: \SymptomEntry.timestamp, order: .reverse) private var allEntries: [SymptomEntry]

    @State private var painLevel: Double = 0
    @State private var painLocation: PainLocation = .none
    @State private var hasNausea = false
    @State private var hasVomiting = false
    @State private var hasFever = false
    @State private var hasChills = false
    @State private var hasBloating = false
    @State private var stoolType: StoolType = .normal
    @State private var notes = ""
    @State private var showingSaveConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Pain") {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Pain Level")
                            Spacer()
                            Text("\(Int(painLevel))/10")
                                .font(.headline.monospacedDigit())
                                .foregroundStyle(painColor)
                        }
                        Slider(value: $painLevel, in: 0...10, step: 1)
                            .tint(painColor)
                    }

                    Picker("Location", selection: $painLocation) {
                        ForEach(PainLocation.allCases, id: \.self) { location in
                            Text(location.rawValue).tag(location)
                        }
                    }
                }

                Section("Associated Symptoms") {
                    Toggle("Nausea", isOn: $hasNausea)
                    Toggle("Vomiting", isOn: $hasVomiting)
                    Toggle("Fever / Feeling Hot", isOn: $hasFever)
                    Toggle("Chills", isOn: $hasChills)
                    Toggle("Bloating", isOn: $hasBloating)
                }

                Section("Digestive") {
                    Picker("Stool Type", selection: $stoolType) {
                        ForEach(StoolType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                }

                Section("Notes") {
                    TextField("Any additional details...", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section {
                    Button(action: saveEntry) {
                        Label("Save Entry", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .listRowBackground(Color.clear)
                }

                if !allEntries.isEmpty {
                    Section("History") {
                        ForEach(allEntries.prefix(10)) { entry in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Pain: \(entry.painLevel)/10")
                                        .font(.subheadline.bold())
                                    Text("— \(entry.painLocation.rawValue)")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                }
                                HStack(spacing: 8) {
                                    if entry.hasNausea { symptomChip("Nausea") }
                                    if entry.hasVomiting { symptomChip("Vomiting") }
                                    if entry.hasFever { symptomChip("Fever") }
                                    if entry.hasBloating { symptomChip("Bloating") }
                                }
                                Text(entry.timestamp, style: .relative)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Log Symptoms")
            .overlay {
                if showingSaveConfirmation {
                    saveConfirmation
                }
            }
        }
    }

    private var painColor: Color {
        switch Int(painLevel) {
        case 0: return .green
        case 1...3: return .yellow
        case 4...6: return .orange
        case 7...10: return .red
        default: return .gray
        }
    }

    private func symptomChip(_ text: String) -> some View {
        Text(text)
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(.orange.opacity(0.2))
            .clipShape(Capsule())
    }

    private func saveEntry() {
        let entry = SymptomEntry(
            painLevel: Int(painLevel),
            painLocation: painLocation,
            hasNausea: hasNausea,
            hasVomiting: hasVomiting,
            hasFever: hasFever,
            hasChills: hasChills,
            hasBloating: hasBloating,
            stoolType: stoolType,
            notes: notes
        )
        modelContext.insert(entry)

        Task {
            try? await healthKit.saveSymptomsToAppleHealth(entry: entry)
        }

        withAnimation {
            showingSaveConfirmation = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showingSaveConfirmation = false
            resetForm()
        }
    }

    private func resetForm() {
        painLevel = 0
        painLocation = .none
        hasNausea = false
        hasVomiting = false
        hasFever = false
        hasChills = false
        hasBloating = false
        stoolType = .normal
        notes = ""
    }

    private var saveConfirmation: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
            Text("Saved")
                .font(.headline)
        }
        .padding(32)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .transition(.scale.combined(with: .opacity))
    }
}
