import SwiftUI

struct ProgramView: View {
    @EnvironmentObject var store: ProgramStore
    @EnvironmentObject var connection: ConnectionManager
    @State private var showNewRun = false
    @State private var editingRun: CarriageRun? = nil
    @State private var showNewSet = false
    @StateObject private var engine = RunEngine()
    @State private var runningRun: CarriageRun? = nil

    var body: some View {
        NavigationView {
            List {
                // ── Cows section ──────────────────────────────────────
                Section {
                    if store.runs.isEmpty {
                        Text("No cows yet — tap + to create one")
                            .foregroundColor(.secondary).font(.subheadline)
                    }
                    ForEach(store.runs) { run in
                        RunRowView(run: run, engine: engine, runningRun: $runningRun)
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

                // ── Sets section ──────────────────────────────────────
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
                            Button(role: .destructive) { store.deleteSet(set) }
                                label: { Label("Delete", systemImage: "trash") }
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
            .navigationTitle("Sets")
            .sheet(isPresented: $showNewRun)  { RunEditorView(run: nil) }
            .sheet(item: $editingRun)         { run in RunEditorView(run: run) }
            .sheet(isPresented: $showNewSet)  { SetEditorView(set: nil) }
        }
    }
}

struct RunRowView: View {
    let run: CarriageRun
    @ObservedObject var engine: RunEngine
    @Binding var runningRun: CarriageRun?
    @EnvironmentObject var connection: ConnectionManager
    var isThisRunning: Bool { engine.isRunning && runningRun?.id == run.id }
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(run.name).fontWeight(.semibold)
                Text("\(run.steps.count) steps · \(String(format: "%.1f", run.totalDuration))s")
                    .font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            Button {
                if isThisRunning { engine.stop(); runningRun = nil }
                else { runningRun = run; engine.start(run: run, connection: connection) }
            } label: {
                Image(systemName: isThisRunning ? "stop.circle.fill" : "play.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(isThisRunning ? .red : .orange)
            }.buttonStyle(.plain)
        }.padding(.vertical, 6)
    }
}

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

struct SetDetailView: View {
    @EnvironmentObject var store: ProgramStore
    let trainingSet: TrainingSet
    var body: some View {
        List {
            ForEach(trainingSet.entries) { entry in
                if let run = store.run(for: entry.runID) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(run.name).fontWeight(.semibold)
                        Text("Rest after: \(String(format: "%.0f", entry.restDuration))s")
                            .font(.caption).foregroundColor(.secondary)
                    }.padding(.vertical, 4)
                }
            }
        }.navigationTitle(trainingSet.name)
    }
}

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
                Section { TextField("Set name", text: $name) } header: { Text("Name") }
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
            .onAppear { if let s = set { name = s.name; entries = s.entries } }
        }
    }
    func save() {
        var s = set ?? TrainingSet(name: name, entries: [])
        s.name = name; s.entries = entries
        store.saveSet(s); dismiss()
    }
}

struct RunPickerView: View {
    @EnvironmentObject var store: ProgramStore
    @Environment(\.dismiss) var dismiss
    var onSelect: (CarriageRun) -> Void
    var body: some View {
        NavigationView {
            List(store.runs) { run in
                Button {
                    onSelect(run); dismiss()
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
