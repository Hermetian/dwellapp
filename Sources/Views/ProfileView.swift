import SwiftUI
import PhotosUI

struct ProfileView: View {
    @StateObject private var profileViewModel = ProfileViewModel()
    @State private var showImagePicker = false
    @State private var showEditProfile = false
    @State private var showChangePassword = false
    @State private var showDeleteAccount = false
    @State private var selectedImage: PhotosPickerItem?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Header
                    VStack(spacing: 16) {
                        // Profile Image
                        ZStack(alignment: .bottomTrailing) {
                            if let user = profileViewModel.user {
                                AsyncImage(url: URL(string: user.profileImageUrl ?? "")) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Image(systemName: "person.circle.fill")
                                        .font(.system(size: 80))
                                        .foregroundColor(.gray)
                                }
                                .frame(width: 120, height: 120)
                                .clipShape(Circle())
                            }
                            
                            PhotosPicker(selection: $selectedImage) {
                                Image(systemName: "camera.circle.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(.blue)
                                    .background(Color.white)
                                    .clipShape(Circle())
                            }
                        }
                        
                        // User Info
                        VStack(spacing: 4) {
                            Text(profileViewModel.user?.name ?? "")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text(profileViewModel.user?.email ?? "")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top)
                    
                    // Stats
                    HStack(spacing: 40) {
                        VStack {
                            Text("\(profileViewModel.myProperties.count)")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("Properties")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        VStack {
                            Text("\(profileViewModel.user?.favoriteListings.count ?? 0)")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("Favorites")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // My Properties
                    VStack(alignment: .leading, spacing: 16) {
                        Text("My Properties")
                            .font(.headline)
                        
                        if profileViewModel.myProperties.isEmpty {
                            Text("You haven't listed any properties yet")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 16) {
                                    ForEach(profileViewModel.myProperties) { property in
                                        ProfilePropertyCard(property: property)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    
                    // Settings
                    VStack(spacing: 0) {
                        SettingsButton(
                            title: "Edit Profile",
                            icon: "person.fill",
                            action: { showEditProfile = true }
                        )
                        
                        SettingsButton(
                            title: "Change Password",
                            icon: "lock.fill",
                            action: { showChangePassword = true }
                        )
                        
                        SettingsButton(
                            title: "Delete Account",
                            icon: "trash.fill",
                            iconColor: .red,
                            action: { showDeleteAccount = true }
                        )
                        
                        SettingsButton(
                            title: "Sign Out",
                            icon: "arrow.right.square.fill",
                            iconColor: .red,
                            action: { profileViewModel.signOut() }
                        )
                    }
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Profile")
            .onChange(of: selectedImage) { _ in
                Task {
                    if let data = try? await selectedImage?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        await profileViewModel.updateProfile(profileImage: image)
                    }
                }
            }
            .sheet(isPresented: $showEditProfile) {
                EditProfileView(user: profileViewModel.user)
            }
            .sheet(isPresented: $showChangePassword) {
                ChangePasswordView()
            }
            .alert("Delete Account", isPresented: $showDeleteAccount) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    Task {
                        await profileViewModel.deleteAccount()
                    }
                }
            } message: {
                Text("Are you sure you want to delete your account? This action cannot be undone.")
            }
            .alert("Error", isPresented: .constant(profileViewModel.error != nil)) {
                Button("OK") {
                    profileViewModel.error = nil
                }
            } message: {
                Text(profileViewModel.error?.localizedDescription ?? "")
            }
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

struct EditProfileView: View {
    let user: User?
    @StateObject private var profileViewModel = ProfileViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Name", text: $name)
                }
                
                Section {
                    Button("Save Changes") {
                        Task {
                            await profileViewModel.updateProfile(name: name)
                            dismiss()
                        }
                    }
                    .disabled(name.isEmpty || profileViewModel.isLoading)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarItems(leading: Button("Cancel") {
                dismiss()
            })
            .onAppear {
                name = user?.name ?? ""
            }
        }
    }
}

struct ChangePasswordView: View {
    @StateObject private var profileViewModel = ProfileViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    
    private var isFormValid: Bool {
        !currentPassword.isEmpty &&
        !newPassword.isEmpty &&
        newPassword == confirmPassword &&
        newPassword.count >= 8
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    SecureField("Current Password", text: $currentPassword)
                    SecureField("New Password", text: $newPassword)
                    SecureField("Confirm New Password", text: $confirmPassword)
                }
                
                Section {
                    Button("Change Password") {
                        Task {
                            await profileViewModel.updatePassword(newPassword: newPassword)
                            dismiss()
                        }
                    }
                    .disabled(!isFormValid || profileViewModel.isLoading)
                }
            }
            .navigationTitle("Change Password")
            .navigationBarItems(leading: Button("Cancel") {
                dismiss()
            })
        }
    }
}

#Preview {
    ProfileView()
} 