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
