import SwiftUI
import ViewModels
import Core

public struct FilterView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appViewModel: AppViewModel
    
    public var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Property Types")) {
                    ForEach(FilterViewModel.propertyTypes, id: \.self) { type in
                        Toggle(type, isOn: Binding(
                            get: { appViewModel.filterViewModel.selectedPropertyTypes.contains(type) },
                            set: { isSelected in
                                if isSelected {
                                    appViewModel.filterViewModel.selectedPropertyTypes.insert(type)
                                } else {
                                    appViewModel.filterViewModel.selectedPropertyTypes.remove(type)
                                }
                                appViewModel.filterViewModel.saveFilters()
                            }
                        ))
                    }
                }
                
                if appViewModel.filterViewModel.selectedPropertyTypes.contains("Vacation Rental") {
                    Section(header: Text("Price per Night")) {
                        PriceRangeSlider(
                            value: Binding(
                                get: { appViewModel.filterViewModel.vacationRentalPriceRange },
                                set: { range in
                                    appViewModel.filterViewModel.vacationRentalPriceRange = range
                                    appViewModel.filterViewModel.saveFilters()
                                }
                            ),
                            range: 0...1000,
                            step: 50
                        )
                    }
                }
                
                if !appViewModel.filterViewModel.selectedPropertyTypes.isDisjoint(with: ["Room (Rent)", "Property (Rent)"]) {
                    Section(header: Text("Price per Month")) {
                        PriceRangeSlider(
                            value: Binding(
                                get: { appViewModel.filterViewModel.rentalPriceRange },
                                set: { range in
                                    appViewModel.filterViewModel.rentalPriceRange = range
                                    appViewModel.filterViewModel.saveFilters()
                                }
                            ),
                            range: 0...10000,
                            step: 100
                        )
                    }
                }
                
                if !appViewModel.filterViewModel.selectedPropertyTypes.isDisjoint(with: ["Condo/Townhouse (Buy)", "House (Buy)"]) {
                    Section(header: Text("Purchase Price")) {
                        PriceRangeSlider(
                            value: Binding(
                                get: { appViewModel.filterViewModel.purchasePriceRange },
                                set: { range in
                                    appViewModel.filterViewModel.purchasePriceRange = range
                                    appViewModel.filterViewModel.saveFilters()
                                }
                            ),
                            range: 0...2000000,
                            step: 50000
                        )
                    }
                }
                
                Section(header: Text("Bedrooms")) {
                    Picker("Bedrooms", selection: Binding(
                        get: { appViewModel.filterViewModel.selectedBedrooms },
                        set: { newValue in
                            appViewModel.filterViewModel.selectedBedrooms = newValue
                            appViewModel.filterViewModel.saveFilters()
                        }
                    )) {
                        ForEach(FilterViewModel.bedroomOptions, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section(header: Text("Bathrooms")) {
                    Picker("Bathrooms", selection: Binding(
                        get: { appViewModel.filterViewModel.selectedBathrooms },
                        set: { newValue in
                            appViewModel.filterViewModel.selectedBathrooms = newValue
                            appViewModel.filterViewModel.saveFilters()
                        }
                    )) {
                        ForEach(FilterViewModel.bathroomOptions, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section(header: Text("Amenities")) {
                    ForEach(FilterViewModel.amenitiesList, id: \.self) { amenity in
                        Toggle(amenity, isOn: Binding(
                            get: { appViewModel.filterViewModel.selectedAmenities.contains(amenity) },
                            set: { isSelected in
                                if isSelected {
                                    appViewModel.filterViewModel.selectedAmenities.insert(amenity)
                                } else {
                                    appViewModel.filterViewModel.selectedAmenities.remove(amenity)
                                }
                                appViewModel.filterViewModel.saveFilters()
                            }
                        ))
                    }
                }
                
                Section {
                    Button("Reset Filters") {
                        appViewModel.filterViewModel.resetFilters()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Filters")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct PriceRangeSlider: View {
    @Binding var value: ClosedRange<Double>
    let range: ClosedRange<Double>
    let step: Double
    
    var body: some View {
        VStack {
            HStack {
                Text(formatPrice(value.lowerBound))
                Spacer()
                Text(formatPrice(value.upperBound))
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
            
            RangeSlider(value: $value, in: range, step: step)
                .frame(height: 44)
        }
    }
    
    private func formatPrice(_ price: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_US")
        return formatter.string(from: NSNumber(value: price)) ?? "$0"
    }
}

#Preview {
    FilterView()
        .environmentObject(AppViewModel())
} 