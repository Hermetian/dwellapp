import Core
import SwiftUI
import ViewModels

public struct FeedView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @State private var searchText = ""
    @State private var showError = false
    @State private var errorMessage = ""
    
    public var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    ForEach(filteredProperties) { property in
                        NavigationLink {
                            PropertyDetailView(property: property)
                        } label: {
                            PropertyCard(property: property)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding()
            }
            .navigationTitle("Properties")
            .searchable(text: $searchText)
            .refreshable {
                do {
                    try await appViewModel.propertyViewModel.loadProperties()
                } catch {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .task {
            do {
                try await appViewModel.propertyViewModel.loadProperties()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
    
    private var filteredProperties: [Property] {
        if searchText.isEmpty {
            return appViewModel.propertyViewModel.properties
        } else {
            return appViewModel.propertyViewModel.properties.filter { property in
                property.title.localizedCaseInsensitiveContains(searchText) ||
                property.description.localizedCaseInsensitiveContains(searchText) ||
                property.address.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
}

#Preview {
    NavigationView {
        FeedView()
            .environmentObject(AppViewModel())
    }
} 