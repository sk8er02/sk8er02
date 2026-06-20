import SwiftUI

struct AlertView: View {
    let riskLevel: RiskLevel
    let activeSignals: [String]

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Image(systemName: iconName)
                    .font(.system(size: 36))
                    .foregroundStyle(riskColor)

                Text(riskLevel.rawValue)
                    .font(.headline)

                Text(recommendation)
                    .font(.caption)
                    .multilineTextAlignment(.center)

                if !activeSignals.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(activeSignals, id: \.self) { signal in
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                                Text(signal)
                                    .font(.caption2)
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }

    private var iconName: String {
        switch riskLevel {
        case .green: return "checkmark.circle.fill"
        case .yellow: return "eye.fill"
        case .orange: return "exclamationmark.triangle.fill"
        case .red: return "exclamationmark.octagon.fill"
        }
    }

    private var riskColor: Color {
        switch riskLevel {
        case .green: return .green
        case .yellow: return .yellow
        case .orange: return .orange
        case .red: return .red
        }
    }

    private var recommendation: String {
        switch riskLevel {
        case .green: return "All normal."
        case .yellow: return "Monitor closely."
        case .orange: return "Consider contacting your doctor."
        case .red: return "Seek medical attention."
        }
    }
}
