import SwiftUI

// Renders an emoji as a UIImage for use in tab bar icons
extension UIImage {
    static func emoji(_ emoji: String, size: CGFloat = 28) -> UIImage {
        let nsString = emoji as NSString
        let font = UIFont.systemFont(ofSize: size)
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let strSize = nsString.size(withAttributes: attrs)
        let renderer = UIGraphicsImageRenderer(size: strSize)
        return renderer.image { _ in
            nsString.draw(at: .zero, withAttributes: attrs)
        }
    }
}

// MARK: - ContentView

struct ContentView: View {
    @EnvironmentObject var connection: ConnectionManager
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            ManualView()
                .tabItem { Label("Manual", systemImage: "hand.point.up.fill") }
                .tag(0)
            ProgramView()
                .tabItem { Label("Saved", systemImage: "list.bullet.rectangle") }
                .tag(1)
            AutoView()
                .tabItem {
                    Label {
                        Text("Cattle Sim")
                    } icon: {
                        Image(uiImage: UIImage.emoji("\u{1F404}"))
                            .renderingMode(.original)
                    }
                }
                .tag(2)
            ConnectView()
                .tabItem { Label("Connect", systemImage: "wifi") }
                .tag(3)
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(4)
        }
        .accentColor(.orange)
        .overlay(alignment: .top) {
            if !connection.isConnected {
                ConnectionBanner(onTap: { selectedTab = 3 })
            }
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @EnvironmentObject var store: ProgramStore
    @State private var showEraseConfirm = false
    @State private var erasedBanner     = false

    var body: some View {
        NavigationView {
            List {
                // Data
                Section {
                    Button(role: .destructive) {
                        showEraseConfirm = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Erase All Data")
                                    .foregroundColor(.red)
                                    .fontWeight(.semibold)
                                Text("Deletes all saved cows, sets and cattle profiles.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } header: { Text("Data") }

                // About
                Section {
                    HStack {
                        Label("App", systemImage: "flag.fill")
                        Spacer()
                        Text("Flag Carriage").foregroundColor(.secondary)
                    }
                    HStack {
                        Label("Version", systemImage: "number")
                        Spacer()
                        Text(appVersion()).foregroundColor(.secondary)
                    }
                } header: { Text("About") }
            }
            .navigationTitle("Settings")
            .confirmationDialog(
                "Erase All Data?",
                isPresented: $showEraseConfirm,
                titleVisibility: .visible
            ) {
                Button("Erase Everything", role: .destructive) {
                    store.eraseAllData()
                    Haptics.notification(.warning)
                    withAnimation { erasedBanner = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        withAnimation { erasedBanner = false }
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will permanently delete all saved cows, training sets, and cattle profiles. This cannot be undone.")
            }
            .overlay(alignment: .bottom) {
                if erasedBanner {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                        Text("All data erased.").fontWeight(.semibold)
                    }
                    .padding(.horizontal, 20).padding(.vertical, 12)
                    .background(.regularMaterial)
                    .cornerRadius(22)
                    .shadow(radius: 6)
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    }

    private func appVersion() -> String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }
}
