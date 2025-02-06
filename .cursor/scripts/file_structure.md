# DwellApp Project Structure

Generated on: 2025-02-06 14:09

```
.
├── AuthViewModel.swift
├── GoogleService-Info.plist
├── Package.resolved
├── Package.swift
├── Sources
│   ├── App
│   │   └── DwellApp.swift
│   ├── Assets.xcassets
│   │   ├── AppIcon.appiconset
│   │   │   ├── Contents.json
│   │   │   ├── Icon-1024.png
│   │   │   ├── Icon-120.png
│   │   │   ├── Icon-180.png
│   │   │   ├── Icon-40.png
│   │   │   ├── Icon-58.png
│   │   │   ├── Icon-60.png
│   │   │   ├── Icon-80.png
│   │   │   ├── Icon-87.png
│   │   │   ├── icon_1024.png
│   │   │   ├── icon_120.png
│   │   │   ├── icon_180.png
│   │   │   ├── icon_40.png
│   │   │   ├── icon_58.png
│   │   │   ├── icon_60.png
│   │   │   ├── icon_80.png
│   │   │   └── icon_87.png
│   │   └── Contents.json
│   ├── Config
│   │   └── FirebaseConfig.swift
│   ├── FirebaseWrapper
│   ├── Info.plist
│   ├── Models
│   │   ├── Conversation.swift
│   │   ├── Message.swift
│   │   ├── Property.swift
│   │   └── User.swift
│   ├── Preview Content
│   │   └── Preview Assets.xcassets
│   │       └── Contents.json
│   ├── Services
│   │   ├── AuthService.swift
│   │   ├── DatabaseService.swift
│   │   ├── FirebaseExtensions.swift
│   │   ├── StorageService.swift
│   │   └── VideoService.swift
│   ├── ViewModels
│   │   ├── AppViewModel.swift
│   │   ├── AuthViewModel.swift
│   │   ├── MessagingViewModel.swift
│   │   ├── ProfileViewModel.swift
│   │   ├── PropertyViewModel.swift
│   │   └── VideoPlayerViewModel.swift
│   ├── Views
│   │   ├── AuthView.swift
│   │   ├── Components
│   │   │   └── RangeSlider.swift
│   │   ├── EmailLinkSignInView.swift
│   │   ├── FavoritesView.swift
│   │   ├── FeedView.swift
│   │   ├── ForgotPasswordView.swift
│   │   ├── LoginView.swift
│   │   ├── MainTabView.swift
│   │   ├── MessagingView.swift
│   │   ├── ProfileView.swift
│   │   ├── PropertyCard.swift
│   │   ├── PropertyDetailView.swift
│   │   ├── RootView.swift
│   │   ├── SearchView.swift
│   │   ├── SignUpView.swift
│   │   └── UploadPropertyView.swift
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

16 directories, 67 files
```

## Key Directories

- `Sources/Views/`: SwiftUI views for the application UI
- `Sources/ViewModels/`: View models following MVVM pattern
- `Sources/Models/`: Data models and entities
- `Sources/Services/`: Business logic and data services
- `Sources/FirebaseWrapper/`: Firebase integration services
- `.cursor/`: Project configuration and automation scripts
