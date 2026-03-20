import SwiftUI

// MARK: - Set Name Generator

enum SetNameGenerator {
    private static let names = [
        "A Walk in the Park", "Sunday Arvo Stroll", "Easy Does It",
        "The Warm Up", "Lazy Lap", "Breezy Tuesday", "Just Getting Started",
        "Gentle Nudge Session", "The Soft Intro", "Moseying Along",
        "Half Awake", "Coffee First", "The Slow Burn",
        "Rolling Hills", "Light Jogging", "Taking the Scenic Route",
        "No Rush Mate", "After Lunch Special", "The Warm Down",
        "Friday Afternoon Feels", "Get Off the Fence", "Full Send",
        "Chaos Theory", "The Pressure Cooker", "Hot Under the Collar",
        "No Mercy", "Buckle Up Buttercup", "Boot Camp",
        "The Rodeo", "Hang On Tight", "Red Mist Rising",
        "Absolute Mayhem", "She's Gonna Blow", "The Wrecking Crew",
        "Advanced Aggression", "Tuesday Mixed Bag", "Something for Everyone",
        "The Classic", "Old Faithful", "Back to Basics",
        "Bread and Butter", "The Foundation", "Standard Issue",
        "Run of the Mill", "The Usual Suspects",
    ]
    static func generate() -> String { names.randomElement() ?? "The Classic" }
}

// MARK: - ProgramView

struct ProgramView: View {
    @EnvironmentObject var store: ProgramStore
    @EnvironmentObject var connection: ConnectionManager
    @State private var showNewRun  = false
    @State private var editingRun: CarriageRun? = nil
    @State private var showNewSet  = false
    @StateObject private var engine = RunEngine()
    @State private var runningRun: CarriageRun? = nil

    var body: some View {
        NavigationView {
            List {
                // Cows
                Section {
                    if store.runs.isEmpty {
                        Text("No cows yet — tap + to create one")
                            .foregroundColor(.secondary).font(.subheadline)
                    }
                    ForEach(store.runs) { run in
                        CowRowView(run: run, engine: engine, runningRun: $runningRun)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) { store.deleteRun(run) }
                                    label: { Label("Delete", systemImage: "trash") }
                                Button { editingRun = run }
                                    label: { Label("Edit", systemImage: "pencil") }
                                    .tint(.orange)
                            }
                    }
                } header: {
                    HStack {
                        Text("Cows")
                        Spacer()
                        Button { showNewRun = true }
                            label: { Image(systemName: "plus.circle.fill").foregroundColor(.orange) }
                    }
                }

                // Sets
                Section {
                    if store.sets.isEmpty {
                        Text("No sets yet").foregroundColor(.secondary).font(.subheadline)
                    }
                    ForEach(store.sets) { set in
                        NavigationLink(destination: SetDetailView(trainingSet: set)) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(set.name).fontWeight(.semibold)
                                Text("\(set.entries.count) cows").font(.caption).foregroundColor(.secondary)
                            }.padding(.vertical, 4)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                store.deleteSet(set)
                                Haptics.impact(.rigid)
                            } label: { Label("Delete", systemImage: "trash") }
                        }
                    }
                } header: {
                    HStack {
                        Text("Sets")
                        Spacer()
                        Button { showNewSet = true }
                            label: { Image(systemName: "plus.circle.fill").foregroundColor(.orange) }
                    }
                }

                if engine.isRunning {
                    Section {
                        RunProgressView(engine: engine)
                    } header: { Text("Running Now") }
                }
            }
            .navigationTitle("Saved")
            .sheet(isPresented: $showNewRun)  { RunEditorView(run: nil) }
            .sheet(item: $editingRun)         { run in RunEditorView(run: run) }
            .sheet(isPresented: $showNewSet)  { SetEditorView(set: nil) }
        }
    }
}

// MARK: - Cow Row

struct CowRowView: View {
    let run: CarriageRun
    @ObservedObject var engine: RunEngine
    @Binding var runningRun: CarriageRun?
    @EnvironmentObject var connection: ConnectionManager
    var isThisRunning: Bool { engine.isRunning && runningRun?.id == run.id }

    var body: some View {
        NavigationLink(destination: CowDetailView(run: run, engine: engine, runningRun: $runningRun)) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(run.name).fontWeight(.semibold)
                    Text("\(run.steps.count) steps · \(String(format: "%.1f", run.totalDuration))s")
                        .font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                Button {
                    if isThisRunning { engine.stop(); runningRun = nil; Haptics.impact(.rigid) }
                    else { runningRun = run; engine.start(run: run, connection: connection); Haptics.impact(.medium) }
                } label: {
                    Image(systemName: isThisRunning ? "stop.circle.fill" : "play.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(isThisRunning ? .red : .orange)
                }.buttonStyle(.plain)
            }.padding(.vertical, 6)
        }
    }
}

// MARK: - Cow Detail View

struct CowDetailView: View {
    let run: CarriageRun
    @ObservedObject var engine: RunEngine
    @Binding var runningRun: CarriageRun?
    @EnvironmentObject var connection: ConnectionManager
    @EnvironmentObject var store: ProgramStore
    @State private var showEdit = false
    var isThisRunning: Bool { engine.isRunning && runningRun?.id == run.id }

    var body: some View {
        List {
            Section {
                HStack { Label("Steps", systemImage: "list.number"); Spacer(); Text("\(run.steps.count)").foregroundColor(.secondary) }
                HStack { Label("Total duration", systemImage: "clock"); Spacer(); Text(String(format: "%.1fs", run.totalDuration)).foregroundColor(.secondary) }
            } header: { Text("Summary") }

            Section {
                ForEach(Array(run.steps.enumerated()), id: \.element.id) { i, step in
                    HStack(spacing: 12) {
                        Text("\(i + 1)")
                            .font(.caption.weight(.bold)).foregroundColor(.white)
                            .frame(width: 22, height: 22).background(Color.orange).clipShape(Circle())
                        Image(systemName: step.direction.icon)
                            .foregroundColor(step.direction == .forward ? .green : step.direction == .backward ? .blue : .orange)
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(step.direction.label).fontWeight(.medium)
                            Text("\(String(format: "%.1f", step.duration))s @ \(Int(Double(step.speed)/255*100))%")
                                .font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.orange.opacity(0.4))
                            .frame(width: CGFloat(step.duration / run.totalDuration * 60), height: 6)
                    }
                }
            } header: { Text("Steps") }

            Section {
                BigActionButton(
                    isRunning: isThisRunning, startLabel: "Run this Cow", stopLabel: "Stop",
                    onStart: { runningRun = run; engine.start(run: run, connection: connection); Haptics.impact(.medium) },
                    onStop:  { engine.stop(); runningRun = nil; Haptics.impact(.rigid) }
                )
                if isThisRunning { RunProgressView(engine: engine) }
            } header: { Text("Playback") }
        }
        .navigationTitle(run.name)
        .navigationBarItems(trailing: Button("Edit") { showEdit = true }.foregroundColor(.orange))
        .sheet(isPresented: $showEdit) { RunEditorView(run: run) }
    }
}

// MARK: - Set Detail View

struct SetDetailView: View {
    @EnvironmentObject var store: ProgramStore
    @EnvironmentObject var connection: ConnectionManager

    @State private var trainingSet: TrainingSet
    @State private var showEdit      = false
    @State private var navigateToSim = false

    init(trainingSet: TrainingSet) {
        _trainingSet = State(initialValue: trainingSet)
    }

    private func syncFromStore() {
        if let updated = store.sets.first(where: { $0.id == trainingSet.id }) {
            trainingSet = updated
        }
    }

    var totalDuration: Double {
        trainingSet.entries.compactMap { store.run(for: $0.runID)?.totalDuration }.reduce(0, +)
    }

    var body: some View {
        List {
            Section {
                HStack { Label("Cows", systemImage: "list.number"); Spacer(); Text("\(trainingSet.entries.count)").foregroundColor(.secondary) }
                HStack { Label("Total duration", systemImage: "clock"); Spacer(); Text(String(format: "%.1fs", totalDuration)).foregroundColor(.secondary) }
            } header: { Text("Summary") }

            Section {
                if trainingSet.entries.isEmpty {
                    Text("No cows in this set yet").foregroundColor(.secondary).font(.subheadline)
                }
                ForEach(Array(trainingSet.entries.enumerated()), id: \.element.id) { i, entry in
                    HStack(spacing: 12) {
                        Text("\(i + 1)")
                            .font(.caption.weight(.bold)).foregroundColor(.white)
                            .frame(width: 22, height: 22).background(Color.orange).clipShape(Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(store.run(for: entry.runID)?.name ?? "Unknown cow").fontWeight(.medium)
                            HStack(spacing: 8) {
                                if let run = store.run(for: entry.runID) {
                                    Text(String(format: "%.1fs", run.totalDuration)).font(.caption).foregroundColor(.secondary)
                                }
                                if i < trainingSet.entries.count - 1 {
                                    Text("· Rest \(Int(entry.restDuration))s").font(.caption).foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) { removeEntry(at: i) }
                            label: { Label("Remove", systemImage: "trash") }
                    }
                }
            } header: { Text("Cows in order") }

            Section {
                NavigationLink(destination: AutoViewPreloaded(set: trainingSet), isActive: $navigateToSim) { EmptyView() }
                Button {
                    Haptics.impact(.medium); navigateToSim = true
                } label: {
                    HStack {
                        Spacer()
                        Image(systemName: "play.circle.fill").font(.title2).foregroundColor(.white)
                        Text("Run this Set").font(.title3.weight(.bold)).foregroundColor(.white)
                        Spacer()
                    }
                    .padding(.vertical, 14).background(Color.orange).cornerRadius(14)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))

                Button {
                    showEdit = true; Haptics.selection()
                } label: {
                    HStack {
                        Spacer()
                        Image(systemName: "pencil").font(.title2).foregroundColor(.orange)
                        Text("Edit Set").font(.title3.weight(.semibold)).foregroundColor(.orange)
                        Spacer()
                    }
                    .padding(.vertical, 14)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.orange.opacity(0.4), lineWidth: 1))
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            } header: { Text("Actions") }
        }
        .navigationTitle(trainingSet.name)
        .sheet(isPresented: $showEdit, onDismiss: syncFromStore) { SetEditorView(set: trainingSet) }
        .onAppear { syncFromStore() }
    }

    func removeEntry(at index: Int) {
        trainingSet.entries.remove(at: index)
        store.saveSet(trainingSet)
        Haptics.impact(.rigid)
    }
}

// MARK: - AutoView Preloaded

struct AutoViewPreloaded: View {
    @EnvironmentObject var store: ProgramStore
    @EnvironmentObject var connection: ConnectionManager
    let set: TrainingSet
    @StateObject private var setEngine = SetEngine()
    @StateObject private var countdown = CountdownEngine()

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 20) {
                    if !connection.isConnected { NotConnectedBanner() }
                    SetSummaryCard(set: set, store: store).padding(.horizontal)
                    BigActionButton(
                        isRunning: setEngine.isRunning || countdown.isCountingDown,
                        startLabel: "Run Set", stopLabel: "Stop",
                        onStart: { countdown.start { setEngine.start(set: set, store: store, connection: connection) } },
                        onStop:  { countdown.cancel(); setEngine.stop() }
                    ).padding(.horizontal)
                    if setEngine.isRunning { SetLiveCard(setEngine: setEngine).padding(.horizontal) }
                    if case .finished = setEngine.phase { FinishedBanner().padding(.horizontal) }
                }.padding(.top)
            }
            if countdown.isCountingDown {
                CountdownOverlay(count: countdown.count) { countdown.cancel(); setEngine.stop() }
            }
        }
        .navigationTitle(set.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Run Progress

struct RunProgressView: View {
    @ObservedObject var engine: RunEngine
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(engine.currentRunName).fontWeight(.semibold)
            ProgressView(value: engine.progress).accentColor(.orange)
            HStack {
                Text("Step \(engine.currentStepIndex + 1)")
                Spacer()
                Text(String(format: "%.1fs remaining", engine.timeRemaining))
            }.font(.caption).foregroundColor(.secondary)
        }
    }
}

// MARK: - Run (Cow) Editor

struct RunEditorView: View {
    @EnvironmentObject var store: ProgramStore
    @Environment(\.dismiss) var dismiss
    let run: CarriageRun?
    @State private var name  = ""
    @State private var steps: [RunStep] = []
    @State private var showAddStep = false
    var body: some View {
        NavigationView {
            List {
                Section { TextField("Cow name", text: $name) } header: { Text("Name") }
                Section {
                    ForEach(steps) { step in StepRow(step: step) }
                        .onDelete { steps.remove(atOffsets: $0) }
                        .onMove   { steps.move(fromOffsets: $0, toOffset: $1) }
                    Button { showAddStep = true } label: { Label("Add Step", systemImage: "plus") }
                } header: {
                    HStack {
                        Text("Steps")
                        Spacer()
                        Text(String(format: "Total: %.1fs", steps.reduce(0) { $0 + $1.duration }))
                            .font(.caption).foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle(run == nil ? "New Cow" : "Edit Cow")
            .navigationBarItems(
                leading:  Button("Cancel") { dismiss() },
                trailing: Button("Save") { save() }.disabled(name.isEmpty || steps.isEmpty)
            )
            .toolbar { EditButton() }
            .sheet(isPresented: $showAddStep) { StepEditorView { steps.append($0) } }
            .onAppear { if let r = run { name = r.name; steps = r.steps } }
        }
    }
    func save() {
        var r = run ?? CarriageRun(name: name, steps: [])
        r.name = name; r.steps = steps
        store.saveRun(r); dismiss()
    }
}

// MARK: - Step Row

struct StepRow: View {
    let step: RunStep
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: step.direction.icon)
                .foregroundColor(step.direction == .forward ? .green : step.direction == .backward ? .blue : .orange)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(step.direction.label).fontWeight(.medium)
                Text("\(String(format: "%.1f", step.duration))s @ \(Int(Double(step.speed)/255*100))%")
                    .font(.caption).foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Step Editor

struct StepEditorView: View {
    @Environment(\.dismiss) var dismiss
    var onSave: (RunStep) -> Void
    @State private var direction: StepDirection = .forward
    @State private var speed: Double = 180
    @State private var duration: Double = 2.0
    var body: some View {
        NavigationView {
            Form {
                Section("Direction") {
                    Picker("Direction", selection: $direction) {
                        ForEach(StepDirection.allCases, id: \.self) { d in
                            Label(d.label, systemImage: d.icon).tag(d)
                        }
                    }.pickerStyle(.segmented)
                }
                Section("Speed") {
                    HStack {
                        Slider(value: $speed, in: 0...255, step: 5)
                        Text("\(Int(speed/255*100))%").monospacedDigit().frame(width: 44)
                    }
                }
                Section("Duration") {
                    HStack {
                        Slider(value: $duration, in: 0.2...10.0, step: 0.1)
                        Text(String(format: "%.1fs", duration)).monospacedDigit().frame(width: 44)
                    }
                }
            }
            .navigationTitle("Add Step")
            .navigationBarItems(
                leading:  Button("Cancel") { dismiss() },
                trailing: Button("Add") {
                    onSave(RunStep(direction: direction, speed: Int(speed), duration: duration))
                    dismiss()
                }
            )
        }
    }
}

// MARK: - Set Editor

struct SetEditorView: View {
    @EnvironmentObject var store: ProgramStore
    @Environment(\.dismiss) var dismiss
    let set: TrainingSet?
    @State private var name = ""
    @State private var entries: [SetEntry] = []
    @State private var showRunPicker = false
    @State private var restDuration: Double = 30
    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack {
                        TextField("Set name", text: $name)
                        Button { name = SetNameGenerator.generate(); Haptics.selection() } label: {
                            Image(systemName: "shuffle").foregroundColor(.orange)
                        }.buttonStyle(.plain)
                    }
                } header: { Text("Name your set") }
                footer: { Text("Auto-generated — tap \(Image(systemName: "shuffle")) for another, or type your own.").font(.caption) }

                Section {
                    ForEach(entries) { entry in
                        if let run = store.run(for: entry.runID) {
                            HStack {
                                Text(run.name)
                                Spacer()
                                Text("Rest \(Int(entry.restDuration))s").font(.caption).foregroundColor(.secondary)
                            }
                        }
                    }.onDelete { entries.remove(atOffsets: $0) }
                    Button { showRunPicker = true } label: { Label("Add Cow", systemImage: "plus") }
                } header: { Text("Cows in order") }

                Section {
                    HStack {
                        Text("Rest between cows")
                        Slider(value: $restDuration, in: 5...120, step: 5)
                        Text("\(Int(restDuration))s").frame(width: 40)
                    }
                } header: { Text("Default rest") }
            }
            .navigationTitle(set == nil ? "New Set" : "Edit Set")
            .navigationBarItems(
                leading:  Button("Cancel") { dismiss() },
                trailing: Button("Save") { save() }.disabled(name.isEmpty || entries.isEmpty)
            )
            .sheet(isPresented: $showRunPicker) {
                RunPickerView { run in entries.append(SetEntry(runID: run.id, restDuration: restDuration)) }
            }
            .onAppear {
                if let s = set { name = s.name; entries = s.entries }
                else { name = SetNameGenerator.generate() }
            }
        }
    }
    func save() {
        var s = set ?? TrainingSet(name: name, entries: [])
        s.name = name.trimmingCharacters(in: .whitespaces).isEmpty ? SetNameGenerator.generate() : name
        s.entries = entries
        store.saveSet(s); dismiss()
    }
}

// MARK: - Run Picker

struct RunPickerView: View {
    @EnvironmentObject var store: ProgramStore
    @Environment(\.dismiss) var dismiss
    var onSelect: (CarriageRun) -> Void
    var body: some View {
        NavigationView {
            List(store.runs) { run in
                Button {
                    onSelect(run); dismiss(); Haptics.selection()
                } label: {
                    VStack(alignment: .leading) {
                        Text(run.name).foregroundColor(.primary)
                        Text("\(run.steps.count) steps · \(String(format: "%.1f", run.totalDuration))s")
                            .font(.caption).foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Pick a Cow")
            .navigationBarItems(trailing: Button("Cancel") { dismiss() })
        }
    }
}
