import Core
import SwiftUI
import ViewModels
#if os(iOS)
import PhotosUI
#endif

public struct ImagePicker: ViewModifier {
    @Binding var isPresented: Bool
    let onSelect: (Data) -> Void
    @State private var selectedItem: PhotosPickerItem?
    
    public func body(content: Content) -> some View {
        content
            #if os(iOS)
            .sheet(isPresented: $isPresented) {
                PhotosPicker(
                    "Select a photo",
                    selection: $selectedItem,
                    matching: .images
                )
                .onChange(of: selectedItem) { newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self) {
                            onSelect(data)
                        }
                    }
                }
            }
            #else
            .fileImporter(
                isPresented: $isPresented,
                allowedContentTypes: [.image]
            ) { result in
                switch result {
                case .success(let url):
                    if let data = try? Data(contentsOf: url) {
                        onSelect(data)
                    }
                case .failure:
                    break
                }
            }
            #endif
    }
}

public struct ProfileImageView: View {
    let imageUrl: String?
    let selectedImageData: Data?
    let onTap: () -> Void
    
    public var body: some View {
        Button(action: onTap) {
            if let imageData = selectedImageData {
                #if os(iOS)
                if let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                }
                #elseif os(macOS)
                if let nsImage = NSImage(data: imageData) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                }
                #endif
            } else {
                AsyncImage(url: URL(string: imageUrl ?? "")) { image in
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
    }
}

public struct ProfileView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @State private var showingEditProfile = false
    @State private var showingSettings = false
    @State private var showingLogoutAlert = false
    @State private var showingImagePicker = false
    @State private var selectedImageData: Data?
    
    public var body: some View {
        NavigationView {
            Form {
                Section {
                    VStack {
                        // Profile Image
                        ProfileImageView(
                            imageUrl: appViewModel.profileViewModel.user?.profileImageUrl,
                            selectedImageData: selectedImageData,
                            onTap: { showingImagePicker = true }
                        )
                        
                        // User Info
                        if let user = appViewModel.profileViewModel.user {
                            Text(user.name)
                                .font(.headline)
                            Text(user.email)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                }
                
                // Rest of the form sections...
                Section {
                    Button("Edit Profile") {
                        showingEditProfile = true
                    }
                    .buttonStyle(.bordered)
                }
                
                Section {
                    actionButtons
                }
                
                Section {
                    statsView
                }
                
                Section {
                    listedPropertiesSection
                }
            }
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    settingsButton
                }
            }
            .sheet(isPresented: $showingEditProfile) {
                EditProfileView()
            }
            .alert("Sign Out", isPresented: $showingLogoutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    Task {
                        try? await appViewModel.authViewModel.signOut()
                    }
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
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
                showingLogoutAlert = true
            } label: {
                VStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.title2)
                    Text("Sign Out")
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

public struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appViewModel: AppViewModel
    @State private var displayName = ""
    @State private var bio = ""
    @State private var showingImagePicker = false
    @State private var selectedImageData: Data?
    
    public var body: some View {
        NavigationView {
            Form {
                Section {
                    ProfileImageSection(
                        selectedImageData: $selectedImageData,
                        profileImageUrl: appViewModel.profileViewModel.user?.profileImageUrl,
                        onImagePickerTap: { showingImagePicker = true }
                    )
                }
                
                Section(header: Text("Profile Information")) {
                    TextField("Display Name", text: $displayName)
                    TextField("Bio", text: $bio, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Edit Profile")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            try? await saveProfile()
                        }
                    }
                }
            }
            .onAppear {
                displayName = appViewModel.profileViewModel.user?.name ?? ""
                bio = appViewModel.profileViewModel.user?.bio ?? ""
            }
            .modifier(ImagePicker(isPresented: $showingImagePicker) { data in
                selectedImageData = data
            })
        }
    }
    
    private func saveProfile() async throws {
        // Save profile logic here
        dismiss()
    }
}

public struct ProfileImageSection: View {
    @Binding var selectedImageData: Data?
    let profileImageUrl: String?
    let onImagePickerTap: () -> Void
    
    public var body: some View {
        HStack {
            Spacer()
            
            Button(action: onImagePickerTap) {
                ProfileImage(
                    imageData: selectedImageData,
                    imageUrl: profileImageUrl
                )
            }
            
            Spacer()
        }
        .listRowBackground(Color.clear)
    }
}

public struct ProfileImage: View {
    let imageData: Data?
    let imageUrl: String?
    
    public var body: some View {
        Group {
            if let imageData = imageData {
                #if os(iOS)
                if let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                }
                #elseif os(macOS)
                if let nsImage = NSImage(data: imageData) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                }
                #endif
            } else {
                AsyncImage(url: URL(string: imageUrl ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.gray)
                }
            }
        }
        .frame(width: 100, height: 100)
        .clipShape(Circle())
    }
}

public struct PropertyListItem: View {
    let property: Property
    
    public var body: some View {
        VStack(alignment: .leading) {
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
        .background(.background)
        .cornerRadius(12)
        .shadow(radius: 4)
    }
}

public struct SettingsButton: View {
    let title: String
    let icon: String
    var iconColor: Color = .blue
    let action: () -> Void
    
    public var body: some View {
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
        .background(.background)
    }
}

public struct ChangePasswordView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    
    public var body: some View {
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
                                try? await appViewModel.profileViewModel.updatePassword(newPassword: newPassword)
                                dismiss()
                            }
                        }
                    }
                    .disabled(newPassword.isEmpty || newPassword != confirmPassword)
                }
            }
            .navigationTitle("Change Password")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        ProfileView()
            .environmentObject(AppViewModel())
    }
} 