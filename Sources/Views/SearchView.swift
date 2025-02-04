import SwiftUI

struct SearchView: View {
    @StateObject private var propertyViewModel = PropertyViewModel()
    @State private var searchText = ""
    @State private var showFilters = false
    @State private var priceRange: ClosedRange<Double> = 0...10000
    @State private var selectedBedrooms: Int = 0
    @State private var selectedBathrooms: Int = 0
    @State private var selectedAmenities: Set<String> = []
    
    var filteredProperties: [Property] {
        propertyViewModel.properties.filter { property in
            let matchesSearch = searchText.isEmpty || 
                property.title.localizedCaseInsensitiveContains(searchText) ||
                property.description.localizedCaseInsensitiveContains(searchText) ||
                property.address.localizedCaseInsensitiveContains(searchText)
            
            let matchesPrice = property.price >= priceRange.lowerBound && 
                             property.price <= priceRange.upperBound
            
            let matchesBedrooms = selectedBedrooms == 0 || 
                                property.bedrooms == selectedBedrooms
            
            let matchesBathrooms = selectedBathrooms == 0 || 
                                 property.bathrooms == selectedBathrooms
            
            let matchesAmenities = selectedAmenities.isEmpty || 
                                 (property.amenities?.keys.contains { selectedAmenities.contains($0) } ?? false)
            
            return matchesSearch && matchesPrice && matchesBedrooms && 
                   matchesBathrooms && matchesAmenities
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search Bar
            SearchBar(text: $searchText)
                .padding()
            
            // Filter Button
            Button(action: { showFilters.toggle() }) {
                HStack {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                    Text("Filters")
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
            .padding(.bottom)
            
            if propertyViewModel.isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .padding()
            } else if filteredProperties.isEmpty {
                EmptySearchView()
            } else {
                // Results List
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(filteredProperties) { property in
                            NavigationLink(destination: PropertyDetailView(property: property, userId: propertyViewModel.currentUserId ?? "")) {
                                PropertyListItem(property: property)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Search")
        .sheet(isPresented: $showFilters) {
            FilterView(
                priceRange: $priceRange,
                selectedBedrooms: $selectedBedrooms,
                selectedBathrooms: $selectedBathrooms,
                selectedAmenities: $selectedAmenities
            )
        }
        .onAppear {
            propertyViewModel.loadProperties()
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("Search properties...", text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
    }
}

struct FilterView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var priceRange: ClosedRange<Double>
    @Binding var selectedBedrooms: Int
    @Binding var selectedBathrooms: Int
    @Binding var selectedAmenities: Set<String>
    
    let amenitiesList = ["Parking", "Pool", "Gym", "Elevator", "Security"]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Price Range")) {
                    RangeSlider(value: $priceRange, in: 0...10000)
                }
                
                Section(header: Text("Bedrooms")) {
                    Picker("Bedrooms", selection: $selectedBedrooms) {
                        Text("Any").tag(0)
                        ForEach(1...5, id: \.self) { num in
                            Text("\(num)").tag(num)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section(header: Text("Bathrooms")) {
                    Picker("Bathrooms", selection: $selectedBathrooms) {
                        Text("Any").tag(0)
                        ForEach(1...4, id: \.self) { num in
                            Text("\(num)").tag(num)
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
            }
            .navigationTitle("Filters")
            .navigationBarItems(
                leading: Button("Reset") {
                    priceRange = 0...10000
                    selectedBedrooms = 0
                    selectedBathrooms = 0
                    selectedAmenities.removeAll()
                },
                trailing: Button("Done") {
                    dismiss()
                }
            )
        }
    }
}

struct EmptySearchView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            
            Text("No properties found")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Try adjusting your search or filters")
                .foregroundColor(.gray)
        }
        .padding()
    }
}

struct PropertyListItem: View {
    let property: Property
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Property Image/Video Preview
            AsyncImage(url: URL(string: property.thumbnailUrl ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Color.gray.opacity(0.3)
            }
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Property Details
            VStack(alignment: .leading, spacing: 8) {
                Text(property.title)
                    .font(.headline)
                
                Text("$\(Int(property.price))/month")
                    .font(.subheadline)
                    .foregroundColor(.blue)
                
                HStack {
                    Label("\(property.bedrooms) beds", systemImage: "bed.double.fill")
                    Spacer()
                    Label("\(property.bathrooms) baths", systemImage: "shower.fill")
                    Spacer()
                    Label("\(Int(property.squareFootage)) sq ft", systemImage: "square.fill")
                }
                .font(.caption)
                .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 5)
    }
}

#Preview {
    NavigationView {
        SearchView()
    }
} 