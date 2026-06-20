import SwiftUI
import SwiftData

struct FoodLogView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(HealthKitManager.self) private var healthKit
    @Query(sort: \FoodEntry.timestamp, order: .reverse) private var allEntries: [FoodEntry]

    @State private var mealType: MealType = .snack
    @State private var foodDescription = ""
    @State private var containsAlcohol = false
    @State private var alcoholType = ""
    @State private var alcoholQuantity = 1
    @State private var isHighFat = false
    @State private var isKnownTrigger = false
    @State private var showingSaveConfirmation = false
    @State private var showingFoodCamera = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
                        showingFoodCamera = true
                    } label: {
                        HStack {
                            Image(systemName: "camera.viewfinder")
                                .font(.title2)
                                .foregroundStyle(.blue)
                            VStack(alignment: .leading) {
                                Text("Scan with Camera")
                                    .font(.subheadline.bold())
                                Text("AI identifies food, fat content & alcohol")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                Section("Meal Details") {
                    Picker("Meal Type", selection: $mealType) {
                        ForEach(MealType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }

                    TextField("What did you eat/drink?", text: $foodDescription, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("Flags") {
                    Toggle("High Fat Content", isOn: $isHighFat)
                    Toggle("Known Trigger Food", isOn: $isKnownTrigger)
                }

                Section("Alcohol") {
                    Toggle("Contains Alcohol", isOn: $containsAlcohol)

                    if containsAlcohol {
                        TextField("Type (beer, wine, spirits...)", text: $alcoholType)
                        Stepper("Standard Drinks: \(alcoholQuantity)", value: $alcoholQuantity, in: 1...20)
                    }
                }

                Section {
                    Button(action: saveEntry) {
                        Label("Save Entry", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(foodDescription.isEmpty)
                    .listRowBackground(Color.clear)
                }

                if !allEntries.isEmpty {
                    Section("Recent Entries") {
                        ForEach(allEntries.prefix(10)) { entry in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(entry.mealType.rawValue)
                                        .font(.caption.bold())
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(.blue.opacity(0.2))
                                        .clipShape(Capsule())

                                    if entry.containsAlcohol {
                                        Image(systemName: "wineglass.fill")
                                            .foregroundStyle(.red)
                                            .font(.caption)
                                    }
                                    if entry.isHighFat {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundStyle(.orange)
                                            .font(.caption)
                                    }
                                    Spacer()
                                }
                                Text(entry.foodDescription)
                                    .font(.subheadline)
                                Text(entry.timestamp, style: .relative)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            .navigationTitle("Food & Drink")
            .sheet(isPresented: $showingFoodCamera) {
                FoodCameraView { result in
                    foodDescription = result.description
                    mealType = result.mealType
                    containsAlcohol = result.isAlcoholic
                    alcoholType = result.alcoholType ?? ""
                    alcoholQuantity = result.estimatedDrinkCount ?? 1
                    isHighFat = result.isHighFat
                    isKnownTrigger = result.isHighFat || result.isAlcoholic
                }
            }
            .overlay {
                if showingSaveConfirmation {
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
        }
    }

    private func saveEntry() {
        let entry = FoodEntry(
            mealType: mealType,
            foodDescription: foodDescription,
            containsAlcohol: containsAlcohol,
            alcoholType: containsAlcohol ? alcoholType : nil,
            alcoholQuantity: containsAlcohol ? alcoholQuantity : nil,
            isHighFat: isHighFat,
            isKnownTrigger: isKnownTrigger
        )
        modelContext.insert(entry)

        Task {
            if containsAlcohol {
                try? await healthKit.saveAlcoholToAppleHealth(drinks: alcoholQuantity)
            }
        }

        withAnimation { showingSaveConfirmation = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showingSaveConfirmation = false
            foodDescription = ""
            containsAlcohol = false
            alcoholType = ""
            alcoholQuantity = 1
            isHighFat = false
            isKnownTrigger = false
        }
    }
}
