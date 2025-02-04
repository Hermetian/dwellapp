import SwiftUI
import Models
import ViewModels

struct SearchView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @State private var searchText = ""
    @State private var showFilters = false
    @State private var selectedPropertyType = "Any"
    @State private var priceRange = 0.0...5000000.0
    @State private var selectedBedrooms = "Any"
    @State private var selectedBathrooms = "Any"
    @State private var selectedAmenities: Set<String> = []
    
    let propertyTypes = ["Any", "House", "Apartment", "Condo", "Townhouse"]
    let bedroomOptions = ["Any", "1", "2", "3", "4+"]
    let bathroomOptions = ["Any", "1", "1.5", "2", "2.5", "3+"]
    let amenitiesList = ["Parking", "Pool", "Gym", "Elevator", "Security", "Furnished", "Pets Allowed", "Laundry"]
    
    var filteredProperties: [Property] {
        appViewModel.propertyViewModel.properties.filter { property in
            // Property Type Filter
            let typeMatches = selectedPropertyType == "Any" || property.type == selectedPropertyType
            
            // Price Filter
            let priceInRange = priceRange.contains(property.price)
            
            // Bedrooms Filter
            let bedroomsMatch: Bool
            if selectedBedrooms == "Any" {
                bedroomsMatch = true
            } else if selectedBedrooms.hasSuffix("+") {
                let minBedrooms = Int(selectedBedrooms.dropLast()) ?? 0
                bedroomsMatch = property.bedrooms >= minBedrooms
            } else {
                bedroomsMatch = property.bedrooms == Int(selectedBedrooms) ?? 0
            }
            
            // Bathrooms Filter
            let bathroomsMatch: Bool
            if selectedBathrooms == "Any" {
                bathroomsMatch = true
            } else if selectedBathrooms.hasSuffix("+") {
                let minBathrooms = Double(selectedBathrooms.dropLast()) ?? 0
                bathroomsMatch = property.bathrooms >= minBathrooms
            } else {
                bathroomsMatch = property.bathrooms == Double(selectedBathrooms) ?? 0
            }
            
            // Amenities Filter (ANY match)
            let amenitiesMatch = selectedAmenities.isEmpty || 
                selectedAmenities.contains { amenity in
                    property.amenities?[amenity] == true
                }
            
            return typeMatches && priceInRange && bedroomsMatch && bathroomsMatch && amenitiesMatch
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("Search properties...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                    
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding()
                
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
        }
        .onAppear {
            Task {
                await appViewModel.propertyViewModel.loadProperties()
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
                    PriceRangeSlider(range: $priceRange)
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
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: Button("Apply") {
                    dismiss()
                }
            )
        }
    }
}

struct PriceRangeSlider: View {
    @Binding var range: ClosedRange<Double>
    
    var body: some View {
        VStack {
            HStack {
                Text("$\(Int(range.lowerBound))")
                Spacer()
                Text("$\(Int(range.upperBound))")
            }
            .font(.caption)
            
            RangeSlider(value: $range, in: 0...5000000)
                .padding(.vertical)
        }
    }
}

#Preview {
    SearchView()
        .environmentObject(AppViewModel())
} 