import SwiftUI

// MARK: - Cow Name Generator

enum CowNameGenerator {
    private static let adjectives = [
        "Dusty", "Rowdy", "Ornery", "Spooky", "Jumpy", "Cranky", "Lazy",
        "Sassy", "Feisty", "Sneaky", "Wobbly", "Grumpy", "Cheeky", "Bolty",
        "Skittish", "Scrappy", "Dozy", "Frisky", "Stompy", "Grouchy",
        "Wooly", "Muddy", "Dizzy", "Shifty", "Twitchy", "Zippy", "Dopey",
        "Breezy", "Loco", "Nervy"
    ]
    private static let names = [
        "Bessie", "Mabel", "Clover", "Daisy", "Brisket", "Ribeye", "Chuck",
        "T-Bone", "Angus", "Hereford", "Blossom", "Buttercup", "Dolly",
        "Gertie", "Nelly", "Patchy", "Rosie", "Winnie", "Elsie", "Agnes",
        "Bertha", "Lulubelle", "Marigold", "Petunia", "Honeydew", "Clarabelle",
        "Gwendolyn", "Penelope", "Brunhilde", "Mathilda"
    ]
    static func generate() -> String {
        "\(adjectives.randomElement() ?? "Rowdy") \(names.randomElement() ?? "Bessie")"
    }
}

// MARK: - ManualView

struct ManualView: View {
    @EnvironmentObject var connection: ConnectionManager
    @EnvironmentObject var store: ProgramStore

    @State private var speed: Double = 200
    @State private var isHoldingLeft  = false
    @State private var isHoldingRight = false

    @State private var bumpProgress: Double       = 0
    @State private var bumpDirection: StepDirection? = nil
    @State private var bumpDisplayTimer: Timer?   = nil

    // Manual-driven local state (only used when NOT in an auto run)
    @State private var manualDirection: String = "S"
    @State private var manualSpeed: Int        = 0

    @StateObject private var recorder  = RunRecorder()
    @State private var showSaveSheet   = false
    @State private var savedBanner     = false
    @State private var autoName        = ""

    var isMoving: Bool { isHoldingLeft || isHoldingRight || bumpDirection != nil }

    // Show auto step label when an engine is driving; manual label otherwise
    var displayDirection: String {
        if !connection.activeStepLabel.isEmpty { return connection.activeStepLabel }
        return manualDirection
    }
    var displaySpeed: Int {
        if !connection.activeStepLabel.isEmpty { return connection.lastStatus.speed }
        return manualSpeed
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {

                if !connection.isConnected { NotConnectedBanner() }
                if recorder.isRecording    { RecordingBar(recorder: recorder) }

                // Auto-run banner — shown when an engine is controlling the carriage
                if !connection.activeStepLabel.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "play.circle.fill").foregroundColor(.orange)
                        Text("Auto run in progress").font(.subheadline.weight(.semibold)).foregroundColor(.orange)
                    }
                    .frame(maxWidth: .infinity).padding(8)
                    .background(Color.orange.opacity(0.1))
                }

                Spacer()

                LocalDirectionIndicator(direction: displayDirection, speed: displaySpeed)
                    .padding(.bottom, 20)

                HStack(alignment: .center, spacing: 16) {
                    // LEFT
                    DirectionColumn(
                        direction: .backward, arrowIcon: "arrow.left", color: .blue, speed: speed,
                        isHolding: $isHoldingLeft, bumpDirection: bumpDirection, bumpProgress: bumpProgress,
                        onBump: { fireBump(direction: .backward) },
                        onHoldPress: {
                            clearBumpState()
                            let spd = Int(speed)
                            connection.setSpeed(spd); connection.backward()
                            recorder.record(direction: .backward, speed: spd)
                            manualDirection = "B"; manualSpeed = spd
                            Haptics.impact(.medium)
                        },
                        onHoldRelease: {
                            connection.stop()
                            recorder.record(direction: .stop, speed: 0)
                            manualDirection = "S"; manualSpeed = 0
                            Haptics.impact(.soft)
                        }
                    )

                    // STOP
                    Button { stopMotor() } label: {
                        VStack(spacing: 5) {
                            Image(systemName: "stop.fill").font(.system(size: 28, weight: .bold))
                            Text("STOP").font(.system(size: 12, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(width: 70, height: 70)
                        .background(Color.red)
                        .clipShape(Circle())
                        .shadow(radius: 4)
                    }

                    // RIGHT
                    DirectionColumn(
                        direction: .forward, arrowIcon: "arrow.right", color: .green, speed: speed,
                        isHolding: $isHoldingRight, bumpDirection: bumpDirection, bumpProgress: bumpProgress,
                        onBump: { fireBump(direction: .forward) },
                        onHoldPress: {
                            clearBumpState()
                            let spd = Int(speed)
                            connection.setSpeed(spd); connection.forward()
                            recorder.record(direction: .forward, speed: spd)
                            manualDirection = "F"; manualSpeed = spd
                            Haptics.impact(.medium)
                        },
                        onHoldRelease: {
                            connection.stop()
                            recorder.record(direction: .stop, speed: 0)
                            manualDirection = "S"; manualSpeed = 0
                            Haptics.impact(.soft)
                        }
                    )
                }

                Spacer()

                VStack(spacing: 10) {
                    HStack {
                        Text("Speed").font(.headline)
                        Spacer()
                        Text("\(Int(speed / 255 * 100))%")
                            .font(.headline).foregroundColor(.orange).monospacedDigit()
                    }.padding(.horizontal)

                    Slider(value: $speed, in: 50...255, step: 5)
                        .accentColor(.orange).padding(.horizontal)
                        .onChange(of: speed) { val in
                            if isMoving { connection.setSpeed(Int(val)); manualSpeed = Int(val) }
                        }

                    HStack(spacing: 12) {
                        ForEach([("Creep", 80), ("Trot", 150), ("Run", 230)], id: \.0) { label, val in
                            Button(label) {
                                speed = Double(val)
                                if isMoving { connection.setSpeed(val); manualSpeed = val }
                                Haptics.selection()
                            }.buttonStyle(PresetButtonStyle())
                        }
                    }

                    Divider().padding(.horizontal)

                    HStack(spacing: 16) {
                        if !recorder.isRecording {
                            Button {
                                recorder.start()
                                Haptics.impact(.medium)
                            } label: {
                                Label("Record Cow", systemImage: "record.circle")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20).padding(.vertical, 10)
                                    .background(Color.red).cornerRadius(22)
                            }
                        } else {
                            Button {
                                recorder.stop()
                                Haptics.impact(.rigid)
                            } label: {
                                Label("Discard", systemImage: "stop.circle")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20).padding(.vertical, 10)
                                    .background(Color.gray).cornerRadius(22)
                            }
                            Button {
                                recorder.stop()
                                autoName = CowNameGenerator.generate()
                                showSaveSheet = true
                            } label: {
                                Label("Save Cow", systemImage: "square.and.arrow.down")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20).padding(.vertical, 10)
                                    .background(Color.orange).cornerRadius(22)
                            }
                            .disabled(recorder.steps.isEmpty)
                        }
                    }
                    .padding(.bottom, 4)

                    if savedBanner {
                        Text("\u{2713} Cow saved")
                            .font(.caption).foregroundColor(.green).transition(.opacity)
                    }
                }
                .padding(.bottom, 32)
                .background(Color(.systemGroupedBackground))
            }
            .navigationTitle("Manual Control")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showSaveSheet) {
                SaveCowSheet(recorder: recorder, suggestedName: autoName) { run in
                    if !run.name.isEmpty {
                        store.saveRun(run)
                        Haptics.notification(.success)
                        withAnimation { savedBanner = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            withAnimation { savedBanner = false }
                        }
                    }
                    showSaveSheet = false
                }
            }
        }
    }

    func stopMotor() {
        clearBumpState()
        connection.stop()
        recorder.record(direction: .stop, speed: 0)
        manualDirection = "S"; manualSpeed = 0
        Haptics.impact(.rigid)
    }

    func fireBump(direction: StepDirection) {
        if bumpDirection == direction { stopMotor(); return }
        clearBumpState()
        bumpDirection = direction; bumpProgress = 0
        let spd = Int(speed)
        connection.setSpeed(spd); connection.send(direction.rawValue)
        recorder.record(direction: direction, speed: spd)
        manualDirection = direction == .forward ? "F" : "B"; manualSpeed = spd
        Haptics.impact(.heavy)
        let bumpDuration = 3.0; let interval = 0.05; var elapsed = 0.0
        bumpDisplayTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [self] t in
            elapsed += interval
            bumpProgress = min(elapsed / bumpDuration, 1.0)
            if elapsed >= bumpDuration {
                t.invalidate(); bumpDisplayTimer = nil
                bumpDirection = nil; bumpProgress = 0
                connection.stop(); recorder.record(direction: .stop, speed: 0)
                manualDirection = "S"; manualSpeed = 0
                Haptics.impact(.soft)
            }
        }
    }

    func clearBumpState() {
        bumpDisplayTimer?.invalidate(); bumpDisplayTimer = nil
        bumpDirection = nil; bumpProgress = 0
    }
}

// MARK: - Save Cow Sheet

struct SaveCowSheet: View {
    @ObservedObject var recorder: RunRecorder
    let suggestedName: String
    var onSave: (CarriageRun) -> Void
    @State private var name = ""
    @FocusState private var nameFocused: Bool
    var cleanSteps: [RunStep] { recorder.cleanedSteps() }
    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack {
                        TextField("Cow name", text: $name).focused($nameFocused)
                        Button { name = CowNameGenerator.generate(); Haptics.selection() } label: {
                            Image(systemName: "shuffle").foregroundColor(.orange)
                        }.buttonStyle(.plain)
                    }
                } header: { Text("Name your cow") }
                footer: { Text("Auto-generated \u{2014} tap \(Image(systemName: "shuffle")) for another, or type your own.").font(.caption) }
                Section {
                    HStack { Text("Total duration"); Spacer()
                        Text(String(format: "%.1fs", cleanSteps.reduce(0) { $0 + $1.duration })).foregroundColor(.secondary) }
                    HStack { Text("Steps"); Spacer(); Text("\(cleanSteps.count)").foregroundColor(.secondary) }
                } header: { Text("Summary") }
                Section { ForEach(cleanSteps) { step in StepRow(step: step) } } header: { Text("Steps preview") }
            }
            .navigationTitle("Save Cow")
            .navigationBarItems(
                leading: Button("Cancel") { onSave(CarriageRun(name: "", steps: [])) },
                trailing: Button("Save") {
                    onSave(CarriageRun(name: name.trimmingCharacters(in: .whitespaces).isEmpty ? suggestedName : name,
                                      steps: cleanSteps))
                }.fontWeight(.semibold).foregroundColor(.orange).disabled(cleanSteps.isEmpty)
            )
            .onAppear { name = suggestedName; nameFocused = false }
        }
    }
}

// MARK: - Local Direction Indicator

struct LocalDirectionIndicator: View {
    let direction: String
    let speed: Int
    var body: some View {
        HStack(spacing: 40) {
            Image(systemName: "arrow.left").font(.title)
                .foregroundColor(direction == "B" ? .blue : .gray.opacity(0.3))
            VStack(spacing: 2) {
                Text(dirLabel).font(.system(size: 22, weight: .bold)).animation(.none, value: dirLabel)
                Text("\(Int(Double(speed) / 255 * 100))% speed")
                    .font(.caption).foregroundColor(.secondary).monospacedDigit()
            }
            Image(systemName: "arrow.right").font(.title)
                .foregroundColor(direction == "F" ? .green : .gray.opacity(0.3))
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(14).padding(.horizontal)
    }
    var dirLabel: String {
        switch direction {
        case "F": return "RIGHT"
        case "B": return "LEFT"
        default:  return "STOPPED"
        }
    }
}

// MARK: - Direction Column

struct DirectionColumn: View {
    let direction: StepDirection
    let arrowIcon: String
    let color: Color
    let speed: Double
    @Binding var isHolding: Bool
    let bumpDirection: StepDirection?
    let bumpProgress: Double
    let onBump: () -> Void
    let onHoldPress: () -> Void
    let onHoldRelease: () -> Void
    var isBumping: Bool { bumpDirection == direction }
    var body: some View {
        VStack(spacing: 12) {
            Button(action: onBump) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(isBumping ? color.opacity(0.15) : Color(.secondarySystemGroupedBackground))
                        .frame(width: 110, height: 70)
                    if isBumping {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .trim(from: 0, to: bumpProgress)
                            .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .frame(width: 110, height: 70)
                            .animation(.linear(duration: 0.05), value: bumpProgress)
                    }
                    VStack(spacing: 3) {
                        Image(systemName: arrowIcon).font(.system(size: 18, weight: .bold))
                        Text("BUMP").font(.system(size: 11, weight: .bold))
                        Text(isBumping ? String(format: "%.1fs", 3.0 * (1 - bumpProgress)) : "3s")
                            .font(.system(size: 10))
                            .foregroundColor(isBumping ? color : .secondary)
                    }
                    .foregroundColor(isBumping ? color : .primary)
                }
            }.buttonStyle(.plain)
            VStack(spacing: 4) {
                Image(systemName: arrowIcon).font(.system(size: 30, weight: .bold))
                Text("MOVE").font(.system(size: 11, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(width: 110, height: 90)
            .background(isHolding ? color.opacity(0.7) : color)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(radius: isHolding ? 2 : 5)
            .scaleEffect(isHolding ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isHolding)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in if !isHolding { isHolding = true; onHoldPress() } }
                    .onEnded   { _ in isHolding = false; onHoldRelease() }
            )
        }
    }
}

// MARK: - RunRecorder

class RunRecorder: ObservableObject {
    @Published var isRecording = false
    @Published var elapsedTime: Double = 0
    @Published private(set) var steps: [RunStep] = []
    private var timer: Timer?
    private var stepStart: Date?
    private var currentDirection: StepDirection = .stop
    private var currentSpeed: Int = 0

    func start() {
        steps = []; elapsedTime = 0; isRecording = true
        stepStart = Date(); currentDirection = .stop; currentSpeed = 0
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in self?.elapsedTime += 0.1 }
    }
    func record(direction: StepDirection, speed: Int) {
        guard isRecording else { return }
        finaliseCurrentStep(); currentDirection = direction; currentSpeed = speed; stepStart = Date()
    }
    func stop() {
        guard isRecording else { return }
        finaliseCurrentStep(); timer?.invalidate(); timer = nil; isRecording = false
    }
    private func finaliseCurrentStep() {
        guard let start = stepStart else { return }
        let duration = Date().timeIntervalSince(start)
        if duration >= 0.1 {
            steps.append(RunStep(direction: currentDirection, speed: currentSpeed,
                                 duration: (duration * 10).rounded() / 10))
        }
        stepStart = nil
    }
    func cleanedSteps() -> [RunStep] {
        var result: [RunStep] = []
        for step in steps {
            if let last = result.last, last.direction == step.direction, last.speed == step.speed {
                var merged = last
                merged.duration = (last.duration + step.duration * 10).rounded() / 10
                result[result.count - 1] = merged
            } else { result.append(step) }
        }
        if result.last?.direction == .stop { result.removeLast() }
        return result
    }
}

// MARK: - Recording bar

struct RecordingBar: View {
    @ObservedObject var recorder: RunRecorder
    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(Color.red).frame(width: 10, height: 10)
                .opacity(recorder.elapsedTime.truncatingRemainder(dividingBy: 1) < 0.5 ? 1 : 0.3)
                .animation(.easeInOut(duration: 0.5).repeatForever(), value: recorder.elapsedTime)
            Text("REC").font(.system(size: 13, weight: .bold)).foregroundColor(.red)
            Spacer()
            Text(timeString(recorder.elapsedTime))
                .font(.system(size: 13, weight: .semibold).monospacedDigit()).foregroundColor(.red)
            Text("\u{00b7} \(recorder.steps.count) steps").font(.caption).foregroundColor(.secondary)
        }
        .padding(.horizontal).padding(.vertical, 8)
        .background(Color.red.opacity(0.08))
    }
    func timeString(_ t: Double) -> String {
        String(format: "%d:%02d.%d", Int(t)/60, Int(t)%60, Int(t*10)%10)
    }
}

// MARK: - Shared UI

struct DriveButton: View {
    let icon: String; let label: String; let color: Color
    @Binding var isHolding: Bool
    let onPress: () -> Void; let onRelease: () -> Void
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
            Text("Not connected \u{2014} go to Settings").font(.subheadline)
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
