import SwiftUI
import SwiftData

struct QuickLogView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var painLevel: Double = 5
    @State private var hasNausea = false
    @State private var hasVomiting = false
    @State private var saved = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text("Quick Log")
                    .font(.headline)

                VStack(spacing: 4) {
                    Text("Pain: \(Int(painLevel))/10")
                        .font(.caption.bold())
                    Slider(value: $painLevel, in: 0...10, step: 1)
                        .tint(painColor)
                }

                Toggle("Nausea", isOn: $hasNausea)
                    .font(.caption)
                Toggle("Vomiting", isOn: $hasVomiting)
                    .font(.caption)

                Button {
                    save()
                } label: {
                    if saved {
                        Label("Saved", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    } else {
                        Label("Save", systemImage: "checkmark")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(saved ? .green : .blue)
                .disabled(saved)
            }
            .padding(.horizontal)
        }
    }

    private var painColor: Color {
        switch Int(painLevel) {
        case 0...3: return .green
        case 4...6: return .orange
        default: return .red
        }
    }

    private func save() {
        let entry = SymptomEntry(
            painLevel: Int(painLevel),
            painLocation: .epigastric,
            hasNausea: hasNausea,
            hasVomiting: hasVomiting
        )
        modelContext.insert(entry)
        saved = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            dismiss()
        }
    }
}
