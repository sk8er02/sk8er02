import Foundation
import SwiftUI
import PhotosUI

#if canImport(FoundationModels)
import FoundationModels
#endif

struct RecognizedFood {
    var description: String
    var isAlcoholic: Bool
    var alcoholType: String?
    var estimatedDrinkCount: Int?
    var isHighFat: Bool
    var estimatedFatGrams: Double?
    var mealType: MealType
    var confidence: String
}

@Observable
final class FoodRecognitionService {
    var isAnalyzing = false
    var lastResult: RecognizedFood?
    var errorMessage: String?

    @available(iOS 27.0, *)
    func analyzeImage(_ image: UIImage) async {
        isAnalyzing = true
        errorMessage = nil
        lastResult = nil

        #if canImport(FoundationModels)
        do {
            let session = LanguageModelSession()

            let prompt = """
            Analyze this food or drink photo. Respond with ONLY a JSON object (no markdown, no explanation):
            {
              "description": "brief description of the food/drink",
              "is_alcoholic": true/false,
              "alcohol_type": "beer/wine/spirits/cocktail/none",
              "estimated_drinks": number or null,
              "is_high_fat": true/false,
              "estimated_fat_grams": number or null,
              "meal_type": "breakfast/lunch/dinner/snack/drink",
              "confidence": "high/medium/low"
            }

            Context: This is for a pancreatitis patient tracking diet triggers.
            High fat means roughly >20g fat per serving.
            Be conservative — flag as high fat if uncertain.
            """

            let response = try await session.respond(to: prompt, attachingImage: image)
            let text = response.content

            if let result = parseResponse(text) {
                lastResult = result
            } else {
                errorMessage = "Could not interpret the image. Try a clearer photo."
            }
        } catch {
            errorMessage = "Analysis unavailable: \(error.localizedDescription)"
        }
        #else
        errorMessage = "Food recognition requires iOS 27 or later with Apple Intelligence enabled."
        #endif

        isAnalyzing = false
    }

    func analyzeWithFallback(_ image: UIImage) async {
        if #available(iOS 27.0, *) {
            await analyzeImage(image)
        } else {
            errorMessage = "Food recognition requires iOS 27+. Please log this meal manually."
            isAnalyzing = false
        }
    }

    private func parseResponse(_ text: String) -> RecognizedFood? {
        var jsonString = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if jsonString.hasPrefix("```json") {
            jsonString = String(jsonString.dropFirst(7))
        }
        if jsonString.hasPrefix("```") {
            jsonString = String(jsonString.dropFirst(3))
        }
        if jsonString.hasSuffix("```") {
            jsonString = String(jsonString.dropLast(3))
        }
        jsonString = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let mealTypeString = (json["meal_type"] as? String) ?? "snack"
        let mealType: MealType = switch mealTypeString {
        case "breakfast": .breakfast
        case "lunch": .lunch
        case "dinner": .dinner
        case "drink": .drink
        default: .snack
        }

        return RecognizedFood(
            description: (json["description"] as? String) ?? "Unknown food",
            isAlcoholic: (json["is_alcoholic"] as? Bool) ?? false,
            alcoholType: json["alcohol_type"] as? String,
            estimatedDrinkCount: json["estimated_drinks"] as? Int,
            isHighFat: (json["is_high_fat"] as? Bool) ?? false,
            estimatedFatGrams: json["estimated_fat_grams"] as? Double,
            mealType: mealType,
            confidence: (json["confidence"] as? String) ?? "low"
        )
    }
}
