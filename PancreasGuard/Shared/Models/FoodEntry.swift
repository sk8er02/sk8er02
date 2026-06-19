import Foundation
import SwiftData

@Model
final class FoodEntry {
    var id: UUID
    var timestamp: Date
    var mealType: MealType
    var foodDescription: String
    var containsAlcohol: Bool
    var alcoholType: String?
    var alcoholQuantity: Int? // standard drinks
    var isHighFat: Bool
    var isKnownTrigger: Bool

    init(
        mealType: MealType = .snack,
        foodDescription: String = "",
        containsAlcohol: Bool = false,
        alcoholType: String? = nil,
        alcoholQuantity: Int? = nil,
        isHighFat: Bool = false,
        isKnownTrigger: Bool = false
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.mealType = mealType
        self.foodDescription = foodDescription
        self.containsAlcohol = containsAlcohol
        self.alcoholType = alcoholType
        self.alcoholQuantity = alcoholQuantity
        self.isHighFat = isHighFat
        self.isKnownTrigger = isKnownTrigger
    }
}

enum MealType: String, Codable, CaseIterable {
    case breakfast = "Breakfast"
    case lunch = "Lunch"
    case dinner = "Dinner"
    case snack = "Snack"
    case drink = "Drink Only"
}
