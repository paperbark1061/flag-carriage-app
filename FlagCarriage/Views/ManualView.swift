import SwiftUI

struct ManualView: View {
    @EnvironmentObject var connection: ConnectionManager
    @State private var speed: Double = 200
    @State private var isHoldingForward  = false
    @State private var isHoldingBackward = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if !connection.isConnected { NotConnectedBanner() }
                Spacer()
                DirectionIndicator(status: connection.lastStatus).padding(.bottom, 24)
                HStack(spacing: 24) {
                    DriveButton(icon: "arrow.left", label: "Back", color: .blue,
                                isHolding: $isHoldingBackward,
                                onPress:   { connection.setSpeed(Int(speed)); connection.backward() },
                                onRelease: { connection.stop() })
                    Button { connection.stop() } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "stop.fill").font(.system(size: 32, weight: .bold))
                            Text("STOP").font(.system(size: 14, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(width: 80, height: 80)
                        .background(Color.red)
                        .clipShape(Circle())
                        .shadow(radius: 4)
                    }
                    DriveButton(icon: "arrow.right", label: "Fwd", color: .green,
                                isHolding: $isHoldingForward,
                                onPress:   { connection.setSpeed(Int(speed)); connection.forward() },
                                onRelease: { connection.stop() })
                }
                Spacer()
                VStack(spacing: 10) {
                    HStack {
                        Text("Speed").font(.headline)
                        Spacer()
                        Text("\(Int(speed / 255 * 100))%").font(.headline).foregroundColor(.orange).monospacedDigit()
                    }.padding(.horizontal)
                    Slider(value: $speed, in: 50...255, step: 5)
                        .accentColor(.orange).padding(.horizontal)
                        .onChange(of: speed) { newVal in
                            if isHoldingForward || isHoldingBackward { connection.setSpeed(Int(newVal)) }
                        }
                    HStack(spacing: 12) {
                        ForEach([("Creep", 80), ("Trot", 150), ("Bolt", 230)], id: \.0) { label, val in
                            Button(label) {
                                speed = Double(val)
                                if isHoldingForward || isHoldingBackward { connection.setSpeed(val) }
                            }.buttonStyle(PresetButtonStyle())
                        }
                    }
                }
                .padding(.bottom, 32)
                .background(Color(.systemGroupedBackground))
            }
            .navigationTitle("Manual Control")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct DriveButton: View {
    let icon: String
    let label: String
    let color: Color
    @Binding var isHolding: Bool
    let onPress: () -> Void
    let onRelease: () -> Void
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 36, weight: .bold))
            Text(label).font(.system(size: 14, weight: .bold))
        }
        .foregroundColor(.white)
        .frame(width: 110, height: 110)
        .background(isHolding ? color.opacity(0.7) : color)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(radius: isHolding ? 2 : 5)
        .scaleEffect(isHolding ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isHolding)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in if !isHolding { isHolding = true; onPress() } }
                .onEnded   { _ in isHolding = false; onRelease() }
        )
    }
}

struct DirectionIndicator: View {
    let status: CarriageStatus
    var body: some View {
        HStack(spacing: 40) {
            Image(systemName: "arrow.left").font(.title)
                .foregroundColor(status.direction == "B" ? .blue : .gray.opacity(0.3))
            VStack(spacing: 2) {
                Text(dirLabel).font(.system(size: 22, weight: .bold))
                Text("\(Int(Double(status.speed)/255*100))% speed").font(.caption).foregroundColor(.secondary)
            }
            Image(systemName: "arrow.right").font(.title)
                .foregroundColor(status.direction == "F" ? .green : .gray.opacity(0.3))
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(14).padding(.horizontal)
    }
    var dirLabel: String {
        switch status.direction {
        case "F": return "FORWARD"
        case "B": return "BACKWARD"
        default:  return "STOPPED"
        }
    }
}

struct PresetButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .padding(.horizontal, 16).padding(.vertical, 8)
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(20)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
    }
}

struct NotConnectedBanner: View {
    var body: some View {
        HStack {
            Image(systemName: "wifi.slash")
            Text("Not connected — go to Connect tab").font(.subheadline)
        }
        .foregroundColor(.white).padding(10)
        .frame(maxWidth: .infinity)
        .background(Color.red.opacity(0.85))
    }
}

struct ConnectionBanner: View {
    let onTap: () -> Void
    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: "wifi.slash")
                Text("Tap to connect").font(.subheadline.weight(.semibold))
                Spacer()
            }
            .foregroundColor(.white).padding(.horizontal).padding(.vertical, 8)
            .background(Color.red.opacity(0.9))
        }.padding(.top, 44)
    }
}
