# DwellApp Project Structure

Generated on: 2025-02-09 01:06

```
.
├── Assets.xcassets
│   ├── AppIcon.appiconset
│   │   ├── Contents.json
│   │   ├── Icon-1024.png
│   │   ├── Icon-120.png
│   │   ├── Icon-152.png
│   │   ├── Icon-167.png
│   │   ├── Icon-180.png
│   │   ├── Icon-20.png
│   │   ├── Icon-29.png
│   │   ├── Icon-40.png
│   │   ├── Icon-58.png
│   │   ├── Icon-60.png
│   │   ├── Icon-76.png
│   │   ├── Icon-80.png
│   │   └── Icon-87.png
│   ├── Contents.json
│   └── Logo.imageset
│       ├── Contents.json
│       └── Logo.png
├── AuthViewModel.swift
├── GoogleService-Info.plist
├── Package.resolved
├── Package.swift
├── Preview Content
│   └── Preview Assets.xcassets
│       └── Contents.json
├── Sources
│   ├── App
│   │   └── DwellApp.swift
│   ├── Config
│   │   └── FirebaseConfig.swift
│   ├── FirebaseWrapper
│   ├── Info.plist
│   ├── Models
│   │   ├── Conversation.swift
│   │   ├── Message.swift
│   │   ├── Property.swift
│   │   ├── PropertyVideo.swift
│   │   └── User.swift
│   ├── Services
│   │   ├── AuthService.swift
│   │   ├── DatabaseService.swift
│   │   ├── FirebaseExtensions.swift
│   │   ├── StorageService.swift
│   │   └── VideoService.swift
│   ├── ViewModels
│   │   ├── AppViewModel.swift
│   │   ├── AuthViewModel.swift
│   │   ├── FilterViewModel.swift
│   │   ├── MessagingViewModel.swift
│   │   ├── ProfileViewModel.swift
│   │   ├── PropertyViewModel.swift
│   │   ├── VideoFeedViewModel.swift
│   │   ├── VideoPlayerViewModel.swift
│   │   └── VideoViewModel.swift
│   ├── Views
│   │   ├── AuthView.swift
│   │   ├── Components
│   │   │   ├── RadialMenu.swift
│   │   │   ├── RangeSlider.swift
│   │   │   └── VideoEditorView.swift
│   │   ├── EmailLinkSignInView.swift
│   │   ├── FavoritesView.swift
│   │   ├── FeedView.swift
│   │   ├── FilterView.swift
│   │   ├── ForgotPasswordView.swift
│   │   ├── LoginView.swift
│   │   ├── MainTabView.swift
│   │   ├── ManagePropertiesView.swift
│   │   ├── ManageVideosView.swift
│   │   ├── MessagingView.swift
│   │   ├── ProfileView.swift
│   │   ├── PropertyCard.swift
│   │   ├── PropertyDetailView.swift
│   │   ├── RootView.swift
│   │   ├── SignUpView.swift
│   │   ├── UploadPropertyView.swift
│   │   ├── VideoMetadataEditorView.swift
│   │   └── VideoUploadView.swift
│   └── dwellapp.entitlements
├── Tests
│   └── dwellappTests.swift
├── UITests
│   ├── dwellappUITests.swift
│   └── dwellappUITestsLaunchTests.swift
├── bugfixes.md
├── dwell-icon-trogdor.svg
├── dwell-icon.svg
├── filestructure.md
├── last_session_summary.md
└── project.yml

17 directories, 76 files
```

## Key Directories

- `Sources/Views/`: SwiftUI views for the application UI
- `Sources/ViewModels/`: View models following MVVM pattern
- `Sources/Models/`: Data models and entities
- `Sources/Services/`: Business logic and data services
- `Sources/FirebaseWrapper/`: Firebase integration services
- `.cursor/`: Project configuration and automation scripts
