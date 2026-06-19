import SwiftUI
import PhotosUI

struct FoodCameraView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var foodRecognition = FoodRecognitionService()
    @State private var showingCamera = false
    @State private var showingPhotoPicker = false
    @State private var capturedImage: UIImage?
    @State private var selectedPhotoItem: PhotosPickerItem?

    var onRecognized: (RecognizedFood) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if let image = capturedImage {
                    imagePreview(image)
                } else {
                    capturePrompt
                }
            }
            .padding()
            .navigationTitle("Scan Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showingCamera) {
                CameraView(image: $capturedImage)
            }
            .onChange(of: capturedImage) {
                if let image = capturedImage {
                    Task { await foodRecognition.analyzeWithFallback(image) }
                }
            }
            .onChange(of: selectedPhotoItem) {
                Task {
                    if let data = try? await selectedPhotoItem?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        capturedImage = image
                    }
                }
            }
        }
    }

    private var capturePrompt: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "camera.viewfinder")
                .font(.system(size: 72))
                .foregroundStyle(.blue)

            Text("Take a photo of your meal or drink")
                .font(.headline)
                .multilineTextAlignment(.center)

            Text("AI will identify the food, estimate fat content, and detect alcohol — all processed on your device.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()

            Button {
                showingCamera = true
            } label: {
                Label("Take Photo", systemImage: "camera.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                Label("Choose from Library", systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
    }

    private func imagePreview(_ image: UIImage) -> some View {
        VStack(spacing: 16) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 250)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            if foodRecognition.isAnalyzing {
                ProgressView("Analyzing with on-device AI...")
                    .padding()
            } else if let result = foodRecognition.lastResult {
                recognitionResultCard(result)
            } else if let error = foodRecognition.errorMessage {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                        .font(.title2)
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }

            HStack(spacing: 12) {
                Button("Retake") {
                    capturedImage = nil
                    foodRecognition.lastResult = nil
                    foodRecognition.errorMessage = nil
                }
                .buttonStyle(.bordered)

                if foodRecognition.lastResult != nil {
                    Button("Use This") {
                        if let result = foodRecognition.lastResult {
                            onRecognized(result)
                            dismiss()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    private func recognitionResultCard(_ result: RecognizedFood) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Detected")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Confidence: \(result.confidence)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(confidenceColor(result.confidence).opacity(0.2))
                    .clipShape(Capsule())
            }

            Text(result.description)
                .font(.headline)

            Divider()

            HStack(spacing: 16) {
                if result.isAlcoholic {
                    Label("\(result.estimatedDrinkCount ?? 1) drink(s)", systemImage: "wineglass.fill")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }
                if result.isHighFat {
                    Label(result.estimatedFatGrams.map { "\(Int($0))g fat" } ?? "High fat", systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                }
                if !result.isAlcoholic && !result.isHighFat {
                    Label("No triggers detected", systemImage: "checkmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.green)
                }
            }

            Text(result.mealType.rawValue)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(.blue.opacity(0.2))
                .clipShape(Capsule())
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func confidenceColor(_ confidence: String) -> Color {
        switch confidence {
        case "high": .green
        case "medium": .orange
        default: .red
        }
    }
}

// UIKit camera wrapper
struct CameraView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView
        init(_ parent: CameraView) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.image = info[.originalImage] as? UIImage
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
