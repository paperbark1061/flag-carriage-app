import SwiftUI

struct AutoView: View {
    @EnvironmentObject var connection: ConnectionManager
    @EnvironmentObject var store: ProgramStore
    @StateObject private var simEngine = CattleSimEngine()
    @StateObject private var runEngine = RunEngine()
    @State private var selectedMode: AutoMode = .random
    @State private var selectedProfile: CattleProfile = CattleProfile.defaults[1]
    @State private var selectedSet: TrainingSet? = nil
    @State private var editingProfile: CattleProfile? = nil

    enum AutoMode: String, CaseIterable {
        case random = "Random"
        case set    = "Training Set"
        var icon: String { self == .random ? "shuffle" : "list.number" }
    }

    var isRunning: Bool { simEngine.isRunning || runEngine.isRunning }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if !connection.isConnected { NotConnectedBanner() }
                    Picker("Mode", selection: $selectedMode) {
                        ForEach(AutoMode.allCases, id: \.self) { mode in
                            Label(mode.rawValue, systemImage: mode.icon).tag(mode)
                        }
                    }.pickerStyle(.segmented).padding(.horizontal)

                    switch selectedMode {
                    case .random:
                        CattleSimPanel(
                            simEngine: simEngine,
                            selectedProfile: $selectedProfile,
                            profiles: store.cattleProfiles,
                            onStart: { simEngine.start(profile: selectedProfile, connection: connection) },
                            onStop:  { simEngine.stop() },
                            onEditProfile: { editingProfile = selectedProfile }
                        )
                    case .set:
                        SetRunPanel(
                            runEngine: runEngine,
                            sets: store.sets,
                            selectedSet: $selectedSet,
                            onStart: {
                                if let set = selectedSet,
                                   let firstID = set.entries.first?.runID,
                                   let firstRun = store.run(for: firstID) {
                                    runEngine.start(run: firstRun, connection: connection)
                                }
                            },
                            onStop: { runEngine.stop() }
                        )
                    }

                    if isRunning {
                        LiveStatusCard(simEngine: simEngine, runEngine: runEngine, mode: selectedMode)
                            .padding(.horizontal)
                    }
                }.padding(.top)
            }
            .navigationTitle("Cattle Sim")
            .sheet(item: $editingProfile) { profile in ProfileEditorView(profile: profile) }
        }
    }
}

struct CattleSimPanel: View {
    @ObservedObject var simEngine: CattleSimEngine
    @Binding var selectedProfile: CattleProfile
    let profiles: [CattleProfile]
    let onStart: () -> Void
    let onStop: () -> Void
    let onEditProfile: () -> Void
    var body: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Cattle Profile").font(.headline).padding(.horizontal)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(profiles) { profile in
                            ProfileCard(profile: profile, isSelected: profile.id == selectedProfile.id)
                                .onTapGesture { selectedProfile = profile }
                        }
                    }.padding(.horizontal)
                }
            }
            ProfileDetailCard(profile: selectedProfile, onEdit: onEditProfile).padding(.horizontal)
            BigActionButton(isRunning: simEngine.isRunning, startLabel: "Start Sim", stopLabel: "Stop",
                            onStart: onStart, onStop: onStop).padding(.horizontal)
        }
    }
}

struct SetRunPanel: View {
    @ObservedObject var runEngine: RunEngine
    let sets: [TrainingSet]
    @Binding var selectedSet: TrainingSet?
    let onStart: () -> Void
    let onStop: () -> Void
    @EnvironmentObject var store: ProgramStore
    var body: some View {
        VStack(spacing: 16) {
            if sets.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "list.bullet.rectangle").font(.largeTitle).foregroundColor(.secondary)
                    Text("No training sets yet").foregroundColor(.secondary)
                    Text("Create sets in the Program tab").font(.caption).foregroundColor(.secondary)
                }.padding()
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Select Training Set").font(.headline).padding(.horizontal)
                    ForEach(sets) { set in
                        SetCard(set: set, isSelected: set.id == selectedSet?.id, store: store)
                            .padding(.horizontal).onTapGesture { selectedSet = set }
                    }
                }
                BigActionButton(isRunning: runEngine.isRunning, startLabel: "Run Set", stopLabel: "Stop",
                                onStart: onStart, onStop: onStop)
                    .padding(.horizontal).disabled(selectedSet == nil)
            }
        }
    }
}

struct LiveStatusCard: View {
    @ObservedObject var simEngine: CattleSimEngine
    @ObservedObject var runEngine: RunEngine
    let mode: AutoView.AutoMode
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Live", systemImage: "dot.radiowaves.left.and.right").font(.headline).foregroundColor(.orange)
            if mode == .random {
                Text(simEngine.currentBehaviour).font(.title3.weight(.semibold))
                Text(String(format: "Running for %.0fs", simEngine.elapsedTime)).font(.caption).foregroundColor(.secondary)
            } else {
                Text(runEngine.currentRunName).font(.title3.weight(.semibold))
                ProgressView(value: runEngine.progress).accentColor(.orange)
                Text(String(format: "%.1fs remaining", runEngine.timeRemaining)).font(.caption).foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
}

struct ProfileCard: View {
    let profile: CattleProfile
    let isSelected: Bool
    var aggressionEmoji: String {
        switch profile.aggression { case .lazy: return "🐄"; case .medium: return "🐂"; case .hot: return "🐃" }
    }
    var aggressionColor: Color {
        switch profile.aggression { case .lazy: return .green; case .medium: return .orange; case .hot: return .red }
    }
    var body: some View {
        VStack(spacing: 6) {
            Text(aggressionEmoji).font(.system(size: 32))
            Text(profile.name).font(.caption.weight(.semibold)).multilineTextAlignment(.center)
            Text(profile.aggression.label).font(.caption2).foregroundColor(.secondary)
        }
        .frame(width: 90, height: 90)
        .background(isSelected ? aggressionColor.opacity(0.2) : Color(.secondarySystemGroupedBackground))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(isSelected ? aggressionColor : Color.clear, lineWidth: 2))
        .cornerRadius(14)
    }
}

struct ProfileDetailCard: View {
    let profile: CattleProfile
    let onEdit: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(profile.name).font(.headline)
                Spacer()
                Button("Edit", action: onEdit).font(.subheadline).foregroundColor(.orange)
            }
            Divider()
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ProfileStat(label: "Speed range",  value: "\(Int(Double(profile.minSpeed)/255*100))–\(Int(Double(profile.maxSpeed)/255*100))%")
                ProfileStat(label: "Run duration", value: "\(String(format: "%.1f", profile.minRunDuration))–\(String(format: "%.1f", profile.maxRunDuration))s")
                ProfileStat(label: "Pause chance", value: "\(Int(profile.pauseChance*100))%")
                ProfileStat(label: "Change freq",  value: "\(String(format: "%.1f", profile.changeFrequency))s")
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
}

struct ProfileStat: View {
    let label: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundColor(.secondary)
            Text(value).font(.subheadline.weight(.semibold))
        }
    }
}

struct SetCard: View {
    let set: TrainingSet
    let isSelected: Bool
    let store: ProgramStore
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(set.name).fontWeight(.semibold)
                Text("\(set.entries.count) runs").font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            if isSelected { Image(systemName: "checkmark.circle.fill").foregroundColor(.orange) }
        }
        .padding()
        .background(isSelected ? Color.orange.opacity(0.1) : Color(.secondarySystemGroupedBackground))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(isSelected ? Color.orange : Color.clear, lineWidth: 1.5))
        .cornerRadius(12)
    }
}

struct BigActionButton: View {
    let isRunning: Bool
    let startLabel: String
    let stopLabel: String
    let onStart: () -> Void
    let onStop: () -> Void
    var body: some View {
        Button {
            if isRunning { onStop() } else { onStart() }
        } label: {
            HStack {
                Spacer()
                Image(systemName: isRunning ? "stop.circle.fill" : "play.circle.fill").font(.title2)
                Text(isRunning ? stopLabel : startLabel).font(.title3.weight(.bold))
                Spacer()
            }
            .foregroundColor(.white).padding(.vertical, 18)
            .background(isRunning ? Color.red : Color.orange)
            .cornerRadius(18)
        }.buttonStyle(.plain)
    }
}
