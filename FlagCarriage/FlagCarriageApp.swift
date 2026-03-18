import SwiftUI

@main
struct FlagCarriageApp: App {
    @StateObject private var connection = ConnectionManager()
    @StateObject private var store = ProgramStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(connection)
                .environmentObject(store)
        }
    }
}
