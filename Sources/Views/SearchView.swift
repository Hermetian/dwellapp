import SwiftUI
import Core
import ViewModels

struct SearchView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appViewModel: AppViewModel
    @State private var showFilters = false
    @State private var selectedPropertyType = "Any"
    @State private var priceRange: ClosedRange<Double> = 0...5000000
    @State private var selectedBedrooms = "Any"
    @State private var selectedBathrooms = "Any"
    @State private var selectedAmenities: Set<String> = []
    
    let propertyTypes = ["Any", "Apartment", "House", "Condo", "Townhouse"]
    let bedroomOptions = ["Any", "1", "2", "3", "4+"]
    let bathroomOptions = ["Any", "1", "1.5", "2", "2.5", "3+"]
    let amenitiesList = ["Parking", "Pool", "Gym", "Elevator", "Security", "Furnished", "Pets Allowed", "Laundry"]
    
    private var filteredProperties: [Property] {
        appViewModel.propertyViewModel.properties.filter { property in
            var matches = true
            
            // Filter by property type
            if selectedPropertyType != "Any" {
                matches = matches && property.type == selectedPropertyType
            }
            
            // Filter by price
            matches = matches && (property.price >= priceRange.lowerBound && property.price <= priceRange.upperBound)
            
            // Filter by bedrooms
            if selectedBedrooms != "Any" {
                let requiredBedrooms = selectedBedrooms == "4+" ? 4 : Int(selectedBedrooms) ?? 0
                matches = matches && (selectedBedrooms == "4+" ? property.bedrooms >= requiredBedrooms : property.bedrooms == requiredBedrooms)
            }
            
            // Filter by bathrooms
            if selectedBathrooms != "Any" {
                let requiredBathrooms = selectedBathrooms == "3+" ? 3 : Double(selectedBathrooms) ?? 0
                matches = matches && (selectedBathrooms == "3+" ? property.bathrooms >= requiredBathrooms : property.bathrooms == requiredBathrooms)
            }
            
            // Filter by amenities
            if !selectedAmenities.isEmpty {
                matches = matches && selectedAmenities.allSatisfy { amenity in
                    property.amenities?[amenity] == true
                }
            }
            
            return matches
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Filter Button
                Button {
                    showFilters = true
                } label: {
                    HStack {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                        Text("Filters")
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .padding(.bottom)
                
                if appViewModel.propertyViewModel.isLoading {
                    ProgressView()
                        .padding()
                } else if filteredProperties.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "house.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No properties found")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Try adjusting your filters")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(filteredProperties) { property in
                                PropertyCard(property: property)
                                    .padding(.horizontal)
                            }
                        }
                        .padding(.vertical)
                    }
                }
            }
            .navigationTitle("Search")
            .sheet(isPresented: $showFilters) {
                FilterView(
                    propertyTypes: propertyTypes,
                    selectedPropertyType: $selectedPropertyType,
                    priceRange: $priceRange,
                    bedroomOptions: bedroomOptions,
                    selectedBedrooms: $selectedBedrooms,
                    bathroomOptions: bathroomOptions,
                    selectedBathrooms: $selectedBathrooms,
                    amenitiesList: amenitiesList,
                    selectedAmenities: $selectedAmenities
                )
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            #if os(macOS)
            .background(Color(nsColor: .windowBackgroundColor))
            #else
            .background(Color(.systemBackground))
            #endif
        }
        .onAppear {
            Task {
                do {
                    try await appViewModel.propertyViewModel.loadProperties()
                } catch {
                    // Handle error if needed
                }
            }
        }
    }
}

struct FilterView: View {
    @Environment(\.dismiss) private var dismiss
    
    let propertyTypes: [String]
    @Binding var selectedPropertyType: String
    @Binding var priceRange: ClosedRange<Double>
    let bedroomOptions: [String]
    @Binding var selectedBedrooms: String
    let bathroomOptions: [String]
    @Binding var selectedBathrooms: String
    let amenitiesList: [String]
    @Binding var selectedAmenities: Set<String>
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Property Type")) {
                    Picker("Type", selection: $selectedPropertyType) {
                        ForEach(propertyTypes, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section(header: Text("Price Range")) {
                    PriceRangeSlider(value: $priceRange, in: 0...5000000)
                }
                
                Section(header: Text("Bedrooms")) {
                    Picker("Bedrooms", selection: $selectedBedrooms) {
                        ForEach(bedroomOptions, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section(header: Text("Bathrooms")) {
                    Picker("Bathrooms", selection: $selectedBathrooms) {
                        ForEach(bathroomOptions, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section(header: Text("Amenities")) {
                    ForEach(amenitiesList, id: \.self) { amenity in
                        Toggle(amenity, isOn: Binding(
                            get: { selectedAmenities.contains(amenity) },
                            set: { isSelected in
                                if isSelected {
                                    selectedAmenities.insert(amenity)
                                } else {
                                    selectedAmenities.remove(amenity)
                                }
                            }
                        ))
                    }
                }
                
                Section {
                    Button("Reset Filters") {
                        selectedPropertyType = "Any"
                        priceRange = 0...5000000
                        selectedBedrooms = "Any"
                        selectedBathrooms = "Any"
                        selectedAmenities.removeAll()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Filters")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct PriceRangeSlider: View {
    @Binding var value: ClosedRange<Double>
    let bounds: ClosedRange<Double>
    
    var body: some View {
        VStack {
            HStack {
                Text("$\(Int(value.lowerBound))")
                Spacer()
                Text("$\(Int(value.upperBound))")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            
            RangeSlider(value: $value, in: bounds)
                .frame(height: 30)
        }
    }
    
    init(value: Binding<ClosedRange<Double>>, in bounds: ClosedRange<Double>) {
        self._value = value
        self.bounds = bounds
    }
}

#Preview {
    NavigationView {
        SearchView()
            .environmentObject(AppViewModel())
    }
} 