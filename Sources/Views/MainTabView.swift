import SwiftUI
import ViewModels

public struct MainTabView: View {
    @EnvironmentObject var appViewModel: AppViewModel
    @State private var selectedTab = 0
    @State private var showFilters = false
    @State private var showRadialMenu = false
    @State private var showNewVideo = false
    @State private var showNewProperty = false
    @State private var showManageVideos = false
    @State private var showManageProperties = false
    
    private var menuItems: [RadialMenuItem] {
        [
            RadialMenuItem(title: "New Video", icon: "video.badge.plus") {
                showNewVideo = true
                showRadialMenu = false
            },
            RadialMenuItem(title: "New Property", icon: "plus.square.fill") {
                showNewProperty = true
                showRadialMenu = false
            },
            RadialMenuItem(title: "Manage Videos", icon: "video.square") {
                showManageVideos = true
                showRadialMenu = false
            },
            RadialMenuItem(title: "Manage Properties", icon: "building.2") {
                showManageProperties = true
                showRadialMenu = false
            }
        ]
    }
    
    public var body: some View {
        ZStack(alignment: .bottom) {
            // Content
            TabView(selection: $selectedTab) {
                NavigationView {
                    FeedView()
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button {
                                    showFilters = true
                                } label: {
                                    Image(systemName: "line.3.horizontal.decrease.circle")
                                }
                            }
                        }
                }
                .tag(0)
                
                NavigationView {
                    MessagingView()
                }
                .tag(1)
                
                NavigationView {
                    ProfileView()
                }
                .tag(2)
            }
            
            // Custom Tab Bar
            VStack(spacing: 0) {
                // Radial Menu Overlay
                if showRadialMenu {
                    Color.black
                        .opacity(0.5)
                        .ignoresSafeArea()
                        .onTapGesture {
                            showRadialMenu = false
                        }
                    
                    RadialMenu(items: menuItems, isPressed: $showRadialMenu)
                        .frame(height: 220)
                        .offset(y: -40) // Position higher above the button
                }
                
                HStack(spacing: 0) {
                    // Feed Tab (Larger)
                    Button {
                        selectedTab = 0
                    } label: {
                        HStack {
                            Image(systemName: selectedTab == 0 ? "house.fill" : "house")
                                .font(.title3)
                            Text("Feed")
                        }
                        .padding(.horizontal)
                        .frame(height: 44)
                        .background(selectedTab == 0 ? Color.blue.opacity(0.1) : Color.clear)
                        .cornerRadius(22)
                    }
                    .foregroundColor(selectedTab == 0 ? .blue : .primary)
                    .frame(width: UIScreen.main.bounds.width * 0.45)
                    
                    // Upload & Manage (Center)
                    VStack(spacing: 2) {
                        Image(systemName: "signpost.right.fill")
                            .font(.title3)
                        Text("List")
                            .font(.caption)
                    }
                    .foregroundColor(showRadialMenu ? .blue : .primary)
                    .frame(width: 60)
                    .frame(width: UIScreen.main.bounds.width * 0.25)
                    .contentShape(Rectangle())  // Make entire area tappable
                    .onTapGesture {
                        showRadialMenu.toggle()
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in
                                if !showRadialMenu {
                                    showRadialMenu = true
                                }
                            }
                            .onEnded { _ in
                                showRadialMenu = false
                            }
                    )
                    
                    // Messages Tab (Icon only)
                    Button {
                        selectedTab = 1
                    } label: {
                        Image(systemName: selectedTab == 1 ? "message.fill" : "message")
                            .font(.title3)
                    }
                    .foregroundColor(selectedTab == 1 ? .blue : .primary)
                    .frame(width: UIScreen.main.bounds.width * 0.15)
                    
                    // Profile Tab (Icon only)
                    Button {
                        selectedTab = 2
                    } label: {
                        Image(systemName: selectedTab == 2 ? "person.fill" : "person")
                            .font(.title3)
                    }
                    .foregroundColor(selectedTab == 2 ? .blue : .primary)
                    .frame(width: UIScreen.main.bounds.width * 0.15)
                }
                .padding(.horizontal)
                .padding(.top, 10)
                .padding(.bottom, 20)
                .background(
                    Rectangle()
                        .fill(.thinMaterial)
                        .ignoresSafeArea()
                )
            }
        }
        .sheet(isPresented: $showFilters) {
            FilterView()
        }
        .sheet(isPresented: $showNewVideo) {
            NewVideoView()
        }
        .sheet(isPresented: $showNewProperty) {
            UploadPropertyView()
        }
        .sheet(isPresented: $showManageVideos) {
            ManageVideosView()
        }
        .sheet(isPresented: $showManageProperties) {
            ManagePropertiesView()
        }
    }
    
    public init() {}
}


#Preview {
    MainTabView()
        .environmentObject(AppViewModel())
}

// Placeholder views - we'll implement these next
struct NewVideoView: View {
    var body: some View {
        Text("New Video View")
    }
}

struct ManageVideosView: View {
    var body: some View {
        Text("Manage Videos View")
    }
}

struct ManagePropertiesView: View {
    var body: some View {
        Text("Manage Properties View")
    }
}