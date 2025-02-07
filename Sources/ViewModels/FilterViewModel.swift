import Core
import Foundation

@MainActor
public final class FilterViewModel: ObservableObject {
    public static let propertyTypes = [
        "Vacation Rental",
        "Room (Rent)",
        "Property (Rent)",
        "Condo/Townhouse (Buy)",
        "House (Buy)"
    ]
    
    public static let bedroomOptions = ["Any", "1", "2", "3", "4+"]
    public static let bathroomOptions = ["Any", "1", "1.5", "2", "2.5", "3+"]
    public static let amenitiesList = ["Parking", "Pool", "Gym", "Elevator", "Security", "Furnished", "Pets Allowed", "Laundry"]
    
    @Published public var selectedPropertyTypes: Set<String> = []
    @Published public var selectedBedrooms = "Any"
    @Published public var selectedBathrooms = "Any"
    @Published public var selectedAmenities: Set<String> = []
    
    // Price ranges for different property types
    @Published public var vacationRentalPriceRange: ClosedRange<Double> = 0...1000 // per night
    @Published public var rentalPriceRange: ClosedRange<Double> = 0...10000 // per month
    @Published public var purchasePriceRange: ClosedRange<Double> = 0...2000000 // total price
    
    public nonisolated init() {
        Task { @MainActor in
            self.setup()
        }
    }
    
    private func setup() {
        loadSavedFilters()
    }
    
    public func isPriceInRange(_ price: Double, for propertyType: String) -> Bool {
        switch propertyType {
        case "Vacation Rental":
            return price >= vacationRentalPriceRange.lowerBound && price <= vacationRentalPriceRange.upperBound
        case "Room (Rent)", "Property (Rent)":
            return price >= rentalPriceRange.lowerBound && price <= rentalPriceRange.upperBound
        case "Condo/Townhouse (Buy)", "House (Buy)":
            return price >= purchasePriceRange.lowerBound && price <= purchasePriceRange.upperBound
        default:
            return true
        }
    }
    
    public func matchesBedroomFilter(_ bedrooms: Int) -> Bool {
        guard selectedBedrooms != "Any" else { return true }
        if selectedBedrooms == "4+" {
            return bedrooms >= 4
        }
        return bedrooms == Int(selectedBedrooms) ?? 0
    }
    
    public func matchesBathroomFilter(_ bathrooms: Double) -> Bool {
        guard selectedBathrooms != "Any" else { return true }
        if selectedBathrooms == "3+" {
            return bathrooms >= 3.0
        }
        return bathrooms == Double(selectedBathrooms) ?? 0
    }
    
    public func matchesAmenitiesFilter(_ propertyAmenities: [String: Bool]?) -> Bool {
        guard !selectedAmenities.isEmpty else { return true }
        guard let propertyAmenities = propertyAmenities else { return false }
        
        return selectedAmenities.allSatisfy { amenity in
            propertyAmenities[amenity] == true
        }
    }
    
    public func saveFilters() {
        let defaults = UserDefaults.standard
        defaults.set(Array(selectedPropertyTypes), forKey: "selectedPropertyTypes")
        defaults.set([vacationRentalPriceRange.lowerBound, vacationRentalPriceRange.upperBound], forKey: "vacationRentalPriceRange")
        defaults.set([rentalPriceRange.lowerBound, rentalPriceRange.upperBound], forKey: "rentalPriceRange")
        defaults.set([purchasePriceRange.lowerBound, purchasePriceRange.upperBound], forKey: "purchasePriceRange")
        defaults.set(selectedBedrooms, forKey: "selectedBedrooms")
        defaults.set(selectedBathrooms, forKey: "selectedBathrooms")
        defaults.set(Array(selectedAmenities), forKey: "selectedAmenities")
    }
    
    public func resetFilters() {
        selectedPropertyTypes.removeAll()
        vacationRentalPriceRange = 0...1000
        rentalPriceRange = 0...10000
        purchasePriceRange = 0...2000000
        selectedBedrooms = "Any"
        selectedBathrooms = "Any"
        selectedAmenities.removeAll()
        saveFilters()
    }
    
    private func loadSavedFilters() {
        let defaults = UserDefaults.standard
        
        if let savedTypes = defaults.array(forKey: "selectedPropertyTypes") as? [String] {
            selectedPropertyTypes = Set(savedTypes)
        }
        
        if let vacationRange = defaults.array(forKey: "vacationRentalPriceRange") as? [Double],
           vacationRange.count == 2 {
            vacationRentalPriceRange = vacationRange[0]...vacationRange[1]
        }
        
        if let rentalRange = defaults.array(forKey: "rentalPriceRange") as? [Double],
           rentalRange.count == 2 {
            rentalPriceRange = rentalRange[0]...rentalRange[1]
        }
        
        if let purchaseRange = defaults.array(forKey: "purchasePriceRange") as? [Double],
           purchaseRange.count == 2 {
            purchasePriceRange = purchaseRange[0]...purchaseRange[1]
        }
        
        selectedBedrooms = defaults.string(forKey: "selectedBedrooms") ?? "Any"
        selectedBathrooms = defaults.string(forKey: "selectedBathrooms") ?? "Any"
        
        if let savedAmenities = defaults.array(forKey: "selectedAmenities") as? [String] {
            selectedAmenities = Set(savedAmenities)
        }
    }
} 