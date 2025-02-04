import SwiftUI
import Models
import UIKit
import ViewModels

struct ProfileView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @State private var showingEditProfile = false
    @State private var showingSettings = false
    @State private var showingLogoutAlert = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Profile Header
                    profileHeader
                    
                    // Action Buttons
                    actionButtons
                    
                    // Stats
                    statsView
                    
                    // Listed Properties
                    listedPropertiesSection
                }
                .padding()
            }
            .navigationTitle("Profile")
            .navigationBarItems(trailing: settingsButton)
            .sheet(isPresented: $showingEditProfile) {
                EditProfileView()
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .alert("Sign Out", isPresented: $showingLogoutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    Task {
                        await appViewModel.authViewModel.signOut()
                    }
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
        }
    }
    
    private var profileHeader: some View {
        VStack(spacing: 16) {
            AsyncImage(url: URL(string: appViewModel.profileViewModel.profileImageUrl ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.gray)
            }
            .frame(width: 100, height: 100)
            .clipShape(Circle())
            
            VStack(spacing: 8) {
                Text(appViewModel.profileViewModel.displayName ?? "User")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(appViewModel.profileViewModel.email ?? "")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Button("Edit Profile") {
                showingEditProfile = true
            }
            .buttonStyle(.bordered)
        }
    }
    
    private var actionButtons: some View {
        HStack(spacing: 20) {
            Button {
                // Favorites action
            } label: {
                VStack {
                    Image(systemName: "heart.fill")
                        .font(.title2)
                    Text("Favorites")
                        .font(.caption)
                }
                .frame(maxWidth: .infinity)
            }
            
            Button {
                // Messages action
            } label: {
                VStack {
                    Image(systemName: "message.fill")
                        .font(.title2)
                    Text("Messages")
                        .font(.caption)
                }
                .frame(maxWidth: .infinity)
            }
            
            Button {
                // Settings action
                showingSettings = true
            } label: {
                VStack {
                    Image(systemName: "gear")
                        .font(.title2)
                    Text("Settings")
                        .font(.caption)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.plain)
    }
    
    private var statsView: some View {
        HStack(spacing: 40) {
            VStack {
                Text("\(appViewModel.propertyViewModel.properties.count)")
                    .font(.title)
                    .fontWeight(.bold)
                Text("Listed")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack {
                Text("\(appViewModel.propertyViewModel.favoriteProperties.count)")
                    .font(.title)
                    .fontWeight(.bold)
                Text("Favorites")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack {
                Text("0") // TODO: Add views count
                    .font(.title)
                    .fontWeight(.bold)
                Text("Views")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical)
    }
    
    private var listedPropertiesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Listed Properties")
                .font(.headline)
            
            if appViewModel.propertyViewModel.properties.isEmpty {
                Text("No properties listed yet")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(appViewModel.propertyViewModel.properties) { property in
                    PropertyCard(property: property)
                }
            }
        }
    }
    
    private var settingsButton: some View {
        Button {
            showingLogoutAlert = true
        } label: {
            Image(systemName: "rectangle.portrait.and.arrow.right")
        }
    }
}

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appViewModel: AppViewModel
    @State private var displayName = ""
    @State private var bio = ""
    @State private var showingImagePicker = false
    @State private var selectedImage: UIImage?
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack {
                        Spacer()
                        
                        Button {
                            showingImagePicker = true
                        } label: {
                            if let selectedImage = selectedImage {
                                Image(uiImage: selectedImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                            } else {
                                AsyncImage(url: URL(string: appViewModel.profileViewModel.profileImageUrl ?? "")) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Image(systemName: "person.circle.fill")
                                        .font(.system(size: 80))
                                        .foregroundColor(.gray)
                                }
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                            }
                        }
                        
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }
                
                Section(header: Text("Profile Information")) {
                    TextField("Display Name", text: $displayName)
                    TextField("Bio", text: $bio, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: Button("Save") {
                    saveProfile()
                }
            )
            .onAppear {
                displayName = appViewModel.profileViewModel.displayName ?? ""
                bio = appViewModel.profileViewModel.bio ?? ""
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(image: $selectedImage)
            }
        }
    }
    
    private func saveProfile() {
        Task {
            if let image = selectedImage {
                await appViewModel.profileViewModel.updateProfile(profileImage: image)
            }
            await appViewModel.profileViewModel.updateProfile(name: displayName, bio: bio)
            dismiss()
        }
    }
}

struct ProfilePropertyCard: View {
    let property: Property
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Property Image
            AsyncImage(url: URL(string: property.thumbnailUrl ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Color.gray
            }
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Property Details
            VStack(alignment: .leading, spacing: 4) {
                Text(property.title)
                    .font(.headline)
                
                Text(property.address)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("$\(Int(property.price))/month")
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 4)
    }
}

struct SettingsButton: View {
    let title: String
    let icon: String
    var iconColor: Color = .blue
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .frame(width: 30)
                
                Text(title)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
        .background(Color(.systemBackground))
    }
}

struct ChangePasswordView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    SecureField("Current Password", text: $currentPassword)
                    SecureField("New Password", text: $newPassword)
                    SecureField("Confirm Password", text: $confirmPassword)
                }
                
                Section {
                    Button("Update Password") {
                        Task {
                            if newPassword == confirmPassword {
                                await appViewModel.profileViewModel.updatePassword(newPassword: newPassword)
                                dismiss()
                            }
                        }
                    }
                    .disabled(newPassword.isEmpty || newPassword != confirmPassword)
                }
            }
            .navigationTitle("Change Password")
            .navigationBarItems(trailing: Button("Cancel") {
                dismiss()
            })
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(AppViewModel())
} 