import SwiftUI

// MARK: - ManualView

struct ManualView: View {
    @EnvironmentObject var connection: ConnectionManager
    @EnvironmentObject var store: ProgramStore

    @State private var speed: Double = 200
    @State private var isHoldingForward  = false
    @State private var isHoldingBackward = false

    // Recording state
    @StateObject private var recorder = RunRecorder()
    @State private var showSaveSheet  = false
    @State private var savedBanner    = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {

                if !connection.isConnected { NotConnectedBanner() }

                // Recording indicator bar
                if recorder.isRecording {
                    RecordingBar(recorder: recorder)
                }

                Spacer()

                DirectionIndicator(status: connection.lastStatus).padding(.bottom, 24)

                // Drive buttons
                HStack(spacing: 24) {
                    DriveButton(icon: "arrow.left", label: "Back", color: .blue,
                                isHolding: $isHoldingBackward,
                                onPress: {
                                    connection.setSpeed(Int(speed))
                                    connection.backward()
                                    recorder.record(direction: .backward, speed: Int(speed))
                                },
                                onRelease: {
                                    connection.stop()
                                    recorder.record(direction: .stop, speed: 0)
                                })

                    // Stop button
                    Button {
                        connection.stop()
                        recorder.record(direction: .stop, speed: 0)
                    } label: {
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
                                onPress: {
                                    connection.setSpeed(Int(speed))
                                    connection.forward()
                                    recorder.record(direction: .forward, speed: Int(speed))
                                },
                                onRelease: {
                                    connection.stop()
                                    recorder.record(direction: .stop, speed: 0)
                                })
                }

                Spacer()

                // Speed + record controls
                VStack(spacing: 10) {

                    // Speed row
                    HStack {
                        Text("Speed").font(.headline)
                        Spacer()
                        Text("\(Int(speed / 255 * 100))%")
                            .font(.headline).foregroundColor(.orange).monospacedDigit()
                    }.padding(.horizontal)

                    Slider(value: $speed, in: 50...255, step: 5)
                        .accentColor(.orange).padding(.horizontal)
                        .onChange(of: speed) { newVal in
                            if isHoldingForward || isHoldingBackward {
                                connection.setSpeed(Int(newVal))
                            }
                        }

                    // Speed presets
                    HStack(spacing: 12) {
                        ForEach([("Creep", 80), ("Trot", 150), ("Bolt", 230)], id: \.0) { label, val in
                            Button(label) {
                                speed = Double(val)
                                if isHoldingForward || isHoldingBackward { connection.setSpeed(val) }
                            }.buttonStyle(PresetButtonStyle())
                        }
                    }

                    Divider().padding(.horizontal)

                    // Record controls
                    HStack(spacing: 16) {
                        if !recorder.isRecording {
                            // Start recording
                            Button {
                                recorder.start()
                            } label: {
                                Label("Record Run", systemImage: "record.circle")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(Color.red)
                                    .cornerRadius(22)
                            }
                        } else {
                            // Stop + discard
                            Button {
                                recorder.stop()
                            } label: {
                                Label("Stop", systemImage: "stop.circle")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(Color.gray)
                                    .cornerRadius(22)
                            }

                            // Save
                            Button {
                                recorder.stop()
                                showSaveSheet = true
                            } label: {
                                Label("Save Run", systemImage: "square.and.arrow.down")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(Color.orange)
                                    .cornerRadius(22)
                            }
                            .disabled(recorder.steps.isEmpty)
                        }
                    }
                    .padding(.bottom, 4)

                    // Saved confirmation
                    if savedBanner {
                        Text("✓ Run saved to Programs")
                            .font(.caption)
                            .foregroundColor(.green)
                            .transition(.opacity)
                    }
                }
                .padding(.bottom, 32)
                .background(Color(.systemGroupedBackground))
            }
            .navigationTitle("Manual Control")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showSaveSheet) {
                SaveRunSheet(recorder: recorder) { run in
                    store.saveRun(run)
                    showSaveSheet = false
                    withAnimation { savedBanner = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        withAnimation { savedBanner = false }
                    }
                }
            }
        }
    }
}

// MARK: - RunRecorder

/// Watches what the user does in Manual mode and converts it into RunSteps.
/// Each time direction or speed changes a new step begins; when direction
/// changes again the previous step's duration is finalised.
class RunRecorder: ObservableObject {
    @Published var isRecording = false
    @Published var elapsedTime: Double = 0
    @Published private(set) var steps: [RunStep] = []

    private var timer: Timer?
    private var stepStart: Date?
    private var currentDirection: StepDirection = .stop
    private var currentSpeed: Int = 0

    func start() {
        steps = []
        elapsedTime = 0
        isRecording = true
        stepStart = Date()
        currentDirection = .stop
        currentSpeed = 0
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.elapsedTime += 0.1
        }
    }

    /// Call this every time a button is pressed or released.
    func record(direction: StepDirection, speed: Int) {
        guard isRecording else { return }
        finaliseCurrentStep()
        currentDirection = direction
        currentSpeed = speed
        stepStart = Date()
    }

    func stop() {
        guard isRecording else { return }
        finaliseCurrentStep()
        timer?.invalidate()
        timer = nil
        isRecording = false
    }

    private func finaliseCurrentStep() {
        guard let start = stepStart else { return }
        let duration = Date().timeIntervalSince(start)
        // Only save steps longer than 0.1s — filters out accidental taps
        if duration >= 0.1 {
            let step = RunStep(
                direction: currentDirection,
                speed: currentSpeed,
                duration: (duration * 10).rounded() / 10   // round to 0.1s
            )
            steps.append(step)
        }
        stepStart = nil
    }

    /// Merge consecutive stop steps and very short duplicate steps to keep
    /// the saved run clean and tidy.
    func cleanedSteps() -> [RunStep] {
        var result: [RunStep] = []
        for step in steps {
            if let last = result.last,
               last.direction == step.direction,
               last.speed == step.speed {
                // Merge — extend the previous step's duration
                var merged = last
                merged.duration = (last.duration + step.duration * 10).rounded() / 10
                result[result.count - 1] = merged
            } else {
                result.append(step)
            }
        }
        // Remove trailing stop (motor always stops at end of playback)
        if result.last?.direction == .stop { result.removeLast() }
        return result
    }
}

// MARK: - Recording bar

struct RecordingBar: View {
    @ObservedObject var recorder: RunRecorder
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.red)
                .frame(width: 10, height: 10)
                .opacity(recorder.elapsedTime.truncatingRemainder(dividingBy: 1) < 0.5 ? 1 : 0.3)
                .animation(.easeInOut(duration: 0.5).repeatForever(), value: recorder.elapsedTime)
            Text("REC")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.red)
            Spacer()
            Text(timeString(recorder.elapsedTime))
                .font(.system(size: 13, weight: .semibold).monospacedDigit())
                .foregroundColor(.red)
            Text("· \(recorder.steps.count) steps")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.red.opacity(0.08))
    }

    func timeString(_ t: Double) -> String {
        let m = Int(t) / 60
        let s = Int(t) % 60
        let d = Int(t * 10) % 10
        return String(format: "%d:%02d.%d", m, s, d)
    }
}

// MARK: - Save sheet

struct SaveRunSheet: View {
    @ObservedObject var recorder: RunRecorder
    var onSave: (CarriageRun) -> Void

    @State private var name = ""
    @FocusState private var nameFocused: Bool

    var cleanSteps: [RunStep] { recorder.cleanedSteps() }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("e.g. Hot cow pattern 1", text: $name)
                        .focused($nameFocused)
                } header: { Text("Run name") }

                Section {
                    HStack {
                        Text("Total duration")
                        Spacer()
                        Text(String(format: "%.1fs", cleanSteps.reduce(0) { $0 + $1.duration }))
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Steps")
                        Spacer()
                        Text("\(cleanSteps.count)").foregroundColor(.secondary)
                    }
                } header: { Text("Summary") }

                Section {
                    ForEach(cleanSteps) { step in StepRow(step: step) }
                } header: { Text("Steps preview") }
            }
            .navigationTitle("Save Recorded Run")
            .navigationBarItems(
                leading: Button("Cancel") { onSave(CarriageRun(name: "", steps: [])) },
                trailing: Button("Save") {
                    let run = CarriageRun(name: name.isEmpty ? "Recorded Run" : name,
                                         steps: cleanSteps)
                    onSave(run)
                }
                .fontWeight(.semibold)
                .foregroundColor(.orange)
                .disabled(cleanSteps.isEmpty)
            )
            .onAppear { nameFocused = true }
        }
    }
}

// MARK: - Shared UI components (unchanged)

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
