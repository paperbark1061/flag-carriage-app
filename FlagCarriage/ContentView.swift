import SwiftUI

struct ContentView: View {
    @EnvironmentObject var connection: ConnectionManager
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            ManualView()
                .tabItem { Label("Manual", systemImage: "hand.point.up.fill") }
                .tag(0)
            ProgramView()
                .tabItem { Label("Sets", systemImage: "list.bullet.rectangle") }
                .tag(1)
            AutoView()
                .tabItem {
                    // SF Symbols has no cow — use the closest cattle-themed icon
                    // with a custom label that makes the intent clear
                    Label {
                        Text("Cattle Sim")
                    } icon: {
                        Image(systemName: "aqi.medium")
                            .symbolRenderingMode(.hierarchical)
                    }
                }
                .tag(2)
            ConnectView()
                .tabItem { Label("Connect", systemImage: "wifi") }
                .tag(3)
        }
        .accentColor(.orange)
        .overlay(alignment: .top) {
            if !connection.isConnected {
                ConnectionBanner(onTap: { selectedTab = 3 })
            }
        }
    }
}
