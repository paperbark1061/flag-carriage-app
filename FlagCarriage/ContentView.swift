import SwiftUI

// Renders an emoji as a UIImage for use in tab bar icons
extension UIImage {
    static func emoji(_ emoji: String, size: CGFloat = 28) -> UIImage {
        let nsString = emoji as NSString
        let font = UIFont.systemFont(ofSize: size)
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let strSize = nsString.size(withAttributes: attrs)
        let renderer = UIGraphicsImageRenderer(size: strSize)
        return renderer.image { _ in nsString.draw(at: .zero, withAttributes: attrs) }
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
                    Label { Text("Cattle Sim") } icon: {
                        Image(uiImage: UIImage.emoji("\u{1F404}")).renderingMode(.original)
                    }
                }
                .tag(2)
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
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

// MARK: - Settings View

struct SettingsView: View {
    @EnvironmentObject var store: ProgramStore
    @EnvironmentObject var connection: ConnectionManager
    @StateObject private var arena = ArenaStore.shared
    @State private var showEraseConfirm = false
    @State private var erasedBanner     = false
    @State private var showArenaSetup   = false

    var body: some View {
        NavigationView {
            List {
                // Connection
                Section {
                    NavigationLink(destination: ConnectView()) {
                        HStack {
                            Image(systemName: connection.isConnected ? "wifi" : "wifi.slash")
                                .foregroundColor(connection.isConnected ? .green : .orange)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Carriage Connection").fontWeight(.semibold)
                                Text(connection.isConnected
                                     ? "Connected \u{2014} \(connection.lastStatus.ip.isEmpty ? connection.ipAddress : connection.lastStatus.ip)"
                                     : "Not connected")
                                    .font(.caption)
                                    .foregroundColor(connection.isConnected ? .green : .secondary)
                            }
                            Spacer()
                        }
                    }
                } header: { Text("Connection") }

                // Arena
                Section {
                    Button { showArenaSetup = true } label: {
                        HStack {
                            Image(systemName: "arrow.left.and.right").foregroundColor(.orange).frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Set Arena").fontWeight(.semibold).foregroundColor(.primary)
                                if let len = arena.lengthSeconds {
                                    Text(String(format: "Rope length: %.1f seconds travel", len))
                                        .font(.caption).foregroundColor(.green)
                                } else {
                                    Text("Not set \u{2014} tap to measure rope length")
                                        .font(.caption).foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    if arena.lengthSeconds != nil {
                        Button(role: .destructive) { arena.clear() } label: {
                            HStack {
                                Image(systemName: "xmark.circle").foregroundColor(.red).frame(width: 28)
                                Text("Clear Arena").foregroundColor(.red)
                            }
                        }
                    }
                } header: { Text("Arena") }
                footer: { Text("Measuring the rope length lets the app cap random run durations so the carriage never hits the end.").font(.caption) }

                // Data
                Section {
                    Button(role: .destructive) { showEraseConfirm = true } label: {
                        HStack {
                            Image(systemName: "trash").foregroundColor(.red).frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Erase All Data").foregroundColor(.red).fontWeight(.semibold)
                                Text("Deletes all saved cows, sets and cattle profiles.")
                                    .font(.caption).foregroundColor(.secondary)
                            }
                        }
                    }
                } header: { Text("Data") }

                // About
                Section {
                    HStack { Label("App", systemImage: "flag.fill"); Spacer(); Text("Flag Carriage").foregroundColor(.secondary) }
                    HStack { Label("Version", systemImage: "number"); Spacer(); Text(appVersion()).foregroundColor(.secondary) }
                } header: { Text("About") }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showArenaSetup) { ArenaSetupView() }
            .confirmationDialog("Erase All Data?", isPresented: $showEraseConfirm, titleVisibility: .visible) {
                Button("Erase Everything", role: .destructive) {
                    store.eraseAllData()
                    Haptics.notification(.warning)
                    withAnimation { erasedBanner = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { withAnimation { erasedBanner = false } }
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
                    .background(.regularMaterial).cornerRadius(22).shadow(radius: 6).padding(.bottom, 20)
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

// MARK: - Arena Setup View
// User holds the right (forward) button while the carriage travels left-to-right.
// When they release, the elapsed time is saved as the arena length.

struct ArenaSetupView: View {
    @EnvironmentObject var connection: ConnectionManager
    @StateObject private var arena = ArenaStore.shared
    @Environment(\.dismiss) var dismiss

    @State private var phase: Phase = .instructions
    @State private var elapsed: Double = 0
    @State private var isHolding = false
    @State private var timer: Timer? = nil

    enum Phase { case instructions, measuring, done }

    var body: some View {
        NavigationView {
            VStack(spacing: 28) {
                Spacer()
                switch phase {
                case .instructions:
                    instructionsView
                case .measuring:
                    measuringView
                case .done:
                    doneView
                }
                Spacer()
            }
            .padding()
            .navigationTitle("Set Arena")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Cancel") { dismiss() })
        }
    }

    // Step 1: Instructions
    var instructionsView: some View {
        VStack(spacing: 20) {
            Image(systemName: "arrow.left.and.right").font(.system(size: 56)).foregroundColor(.orange)
            Text("Measure Your Rope").font(.title2.weight(.bold))
            VStack(alignment: .leading, spacing: 10) {
                Label("Position the carriage at the far LEFT end of the rope.", systemImage: "1.circle.fill")
                Label("Make sure the carriage is connected.", systemImage: "2.circle.fill")
                Label("Press and HOLD the button below while the carriage travels to the far RIGHT end.", systemImage: "3.circle.fill")
                Label("Release when it reaches the end. The app saves the travel time as your arena length.", systemImage: "4.circle.fill")
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(14)

            Button { phase = .measuring } label: {
                Text("I'm Ready")
                    .font(.title3.weight(.bold)).foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(Color.orange).cornerRadius(16)
            }
            .disabled(!connection.isConnected)
            if !connection.isConnected {
                Text("Connect to the carriage first in Settings \u{2192} Carriage Connection")
                    .font(.caption).foregroundColor(.red).multilineTextAlignment(.center)
            }
        }
    }

    // Step 2: Hold-to-measure button
    var measuringView: some View {
        VStack(spacing: 24) {
            Text("Hold to measure")
                .font(.title2.weight(.bold))
            Text("Press and hold the button while the carriage travels to the right end of the rope.")
                .font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center)

            // Big elapsed timer
            ZStack {
                Circle().stroke(Color.green.opacity(0.2), lineWidth: 8).frame(width: 140, height: 140)
                Circle()
                    .trim(from: 0, to: min(elapsed / 30.0, 1.0))   // show progress up to 30s
                    .stroke(Color.green, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 140, height: 140).rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.1), value: elapsed)
                VStack(spacing: 2) {
                    Text(String(format: "%.1f", elapsed))
                        .font(.system(size: 40, weight: .black, design: .rounded)).foregroundColor(.green)
                    Text("seconds").font(.caption).foregroundColor(.secondary)
                }
            }

            // Hold button
            Text(isHolding ? "Moving\u{2026}" : "Hold to move")
                .font(.headline)
                .foregroundColor(isHolding ? .green : .primary)

            Image(systemName: "arrow.right")
                .font(.system(size: 44, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 130, height: 130)
                .background(isHolding ? Color.green.opacity(0.8) : Color.green)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .shadow(radius: isHolding ? 2 : 6)
                .scaleEffect(isHolding ? 0.95 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: isHolding)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            if !isHolding {
                                isHolding = true
                                elapsed = 0
                                connection.setSpeed(200)
                                connection.forward()
                                Haptics.impact(.medium)
                                timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                                    elapsed += 0.1
                                }
                            }
                        }
                        .onEnded { _ in
                            isHolding = false
                            timer?.invalidate(); timer = nil
                            connection.stop()
                            Haptics.notification(.success)
                            if elapsed >= 0.5 {
                                arena.lengthSeconds = (elapsed * 10).rounded() / 10
                                phase = .done
                            }
                        }
                )

            if elapsed < 0.5 {
                Text("Hold for at least 0.5 seconds").font(.caption).foregroundColor(.secondary)
            }
        }
    }

    // Step 3: Confirmation
    var doneView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64)).foregroundColor(.green)
            Text("Arena Set!").font(.title.weight(.bold))
            if let len = arena.lengthSeconds {
                Text(String(format: "Rope length recorded as %.1f seconds of travel.", len))
                    .font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center)
                Text("Random runs will now be capped to stay within the arena.")
                    .font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center)
            }
            Button {
                phase = .measuring
                elapsed = 0
            } label: {
                Text("Measure Again")
                    .font(.subheadline.weight(.semibold)).foregroundColor(.orange)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.orange.opacity(0.4), lineWidth: 1))
            }
            Button { dismiss() } label: {
                Text("Done")
                    .font(.title3.weight(.bold)).foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(Color.orange).cornerRadius(16)
            }
        }
    }
}
