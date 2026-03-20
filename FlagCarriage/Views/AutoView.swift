import SwiftUI

// MARK: - AutoView

struct AutoView: View {
    @EnvironmentObject var connection: ConnectionManager
    @EnvironmentObject var store: ProgramStore

    @StateObject private var simEngine  = CattleSimEngine()
    @StateObject private var setEngine  = SetEngine()
    @StateObject private var countdown  = CountdownEngine()

    @State private var selectedMode: AutoMode         = .freeRange
    @State private var selectedProfile: CattleProfile? = nil    // nil = nothing explicitly chosen
    @State private var selectedSet: TrainingSet?       = nil
    @State private var editingProfile: CattleProfile?  = nil
    @State private var showNoProfileSheet              = false  // action sheet when no profile

    enum AutoMode: String, CaseIterable {
        case freeRange = "Free Range"
        case set       = "Training Set"
        var icon: String { self == .freeRange ? "shuffle" : "list.number" }
    }

    var isActive: Bool { simEngine.isRunning || setEngine.isRunning || countdown.isCountingDown }

    var body: some View {
        NavigationView {
            ZStack {
                ScrollView {
                    VStack(spacing: 20) {
                        if !connection.isConnected { NotConnectedBanner() }

                        Picker("Mode", selection: $selectedMode) {
                            ForEach(AutoMode.allCases, id: \.self) { mode in
                                Label(mode.rawValue, systemImage: mode.icon).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        .disabled(isActive)

                        switch selectedMode {
                        case .freeRange:
                            CattleSimPanel(
                                simEngine: simEngine,
                                selectedProfile: $selectedProfile,
                                profiles: store.cattleProfiles,
                                isCountingDown: countdown.isCountingDown,
                                onStart: {
                                    if selectedProfile == nil {
                                        // No profile chosen — ask what to do
                                        showNoProfileSheet = true
                                    } else {
                                        startFreeRange(wildSide: false)
                                    }
                                },
                                onStop: {
                                    countdown.cancel()
                                    simEngine.stop()
                                },
                                onEditProfile: {
                                    if let p = selectedProfile { editingProfile = p }
                                }
                            )

                        case .set:
                            SetRunPanel(
                                setEngine: setEngine,
                                sets: store.sets,
                                selectedSet: $selectedSet,
                                store: store,
                                isCountingDown: countdown.isCountingDown,
                                onStart: {
                                    guard let set = selectedSet else { return }
                                    countdown.start {
                                        setEngine.start(set: set, store: store, connection: connection)
                                    }
                                },
                                onStop: {
                                    countdown.cancel()
                                    setEngine.stop()
                                }
                            )
                        }

                        // Live cards
                        if simEngine.isRunning {
                            SimLiveCard(simEngine: simEngine).padding(.horizontal)
                        }
                        if setEngine.isRunning {
                            SetLiveCard(setEngine: setEngine).padding(.horizontal)
                        }
                        if case .finished = setEngine.phase {
                            FinishedBanner().padding(.horizontal)
                        }
                    }
                    .padding(.top)
                }

                // 5-second countdown overlay
                if countdown.isCountingDown {
                    CountdownOverlay(count: countdown.count) {
                        countdown.cancel()
                        simEngine.stop()
                        setEngine.stop()
                    }
                }
            }
            .navigationTitle("Cattle Sim")
            .sheet(item: $editingProfile) { profile in ProfileEditorView(profile: profile) }
            // No-profile action sheet
            .confirmationDialog(
                "No Cattle Profile Selected",
                isPresented: $showNoProfileSheet,
                titleVisibility: .visible
            ) {
                Button("\u{1F92A} Live on the Wild Side") {
                    startFreeRange(wildSide: true)
                }
                Button("Choose a Profile") {
                    // Dismiss — user taps a profile card themselves
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Pick a cattle profile, or go wild and let the profiles rotate randomly throughout the session.")
            }
        }
    }

    // MARK: - Start helpers

    private func startFreeRange(wildSide: Bool) {
        if wildSide {
            countdown.start {
                simEngine.startWildSide(profiles: store.cattleProfiles, connection: connection)
            }
        } else if let profile = selectedProfile {
            countdown.start {
                simEngine.start(profile: profile, connection: connection)
            }
        }
    }
}

// MARK: - Countdown Overlay

struct CountdownOverlay: View {
    let count: Int
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.72).ignoresSafeArea()
            VStack(spacing: 28) {
                Text("Get Ready")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                ZStack {
                    Circle()
                        .stroke(Color.orange.opacity(0.3), lineWidth: 8)
                        .frame(width: 160, height: 160)
                    Circle()
                        .trim(from: 0, to: CGFloat(count) / 5.0)
                        .stroke(Color.orange, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 160, height: 160)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1.0), value: count)
                    Text("\(count)")
                        .font(.system(size: 80, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: count)
                }
                Text("Starting in \(count) second\(count == 1 ? "" : "s")...")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                Button {
                    onCancel()
                } label: {
                    Text("Cancel")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 36).padding(.vertical, 12)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(22)
                }
            }
        }
    }
}

// MARK: - Cattle Sim Panel

struct CattleSimPanel: View {
    @ObservedObject var simEngine: CattleSimEngine
    @Binding var selectedProfile: CattleProfile?
    let profiles: [CattleProfile]
    let isCountingDown: Bool
    let onStart: () -> Void
    let onStop: () -> Void
    let onEditProfile: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Cattle Profile").font(.headline)
                    Spacer()
                    if selectedProfile != nil {
                        Button("Clear") {
                            selectedProfile = nil
                            Haptics.selection()
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(profiles) { profile in
                            ProfileCard(
                                profile: profile,
                                isSelected: profile.id == selectedProfile?.id
                            )
                            .onTapGesture {
                                if !simEngine.isRunning {
                                    selectedProfile = profile
                                    Haptics.selection()
                                }
                            }
                        }
                    }.padding(.horizontal)
                }
            }

            // Show detail card only when a profile is selected
            if let profile = selectedProfile {
                ProfileDetailCard(profile: profile, onEdit: onEditProfile).padding(.horizontal)
            } else {
                // Placeholder nudge
                HStack(spacing: 10) {
                    Text("\u{1F914}")
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("No profile selected")
                            .font(.subheadline.weight(.semibold))
                        Text("Tap a profile above, or start for a surprise.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(14)
                .padding(.horizontal)
            }

            BigActionButton(
                isRunning: simEngine.isRunning || isCountingDown,
                startLabel: selectedProfile == nil ? "Start Free Range \u{1F92F}" : "Start Free Range",
                stopLabel: "Stop",
                onStart: onStart,
                onStop: onStop
            ).padding(.horizontal)
        }
    }
}

// MARK: - Set Run Panel

struct SetRunPanel: View {
    @ObservedObject var setEngine: SetEngine
    let sets: [TrainingSet]
    @Binding var selectedSet: TrainingSet?
    let store: ProgramStore
    let isCountingDown: Bool
    let onStart: () -> Void
    let onStop: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            if sets.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "list.bullet.rectangle").font(.largeTitle).foregroundColor(.secondary)
                    Text("No training sets yet").foregroundColor(.secondary)
                    Text("Create sets in the Saved tab").font(.caption).foregroundColor(.secondary)
                }.padding()
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Select Training Set").font(.headline).padding(.horizontal)
                    ForEach(sets) { set in
                        SetCard(set: set, isSelected: set.id == selectedSet?.id, store: store)
                            .padding(.horizontal)
                            .onTapGesture {
                                if !setEngine.isRunning {
                                    selectedSet = set
                                    Haptics.selection()
                                }
                            }
                    }
                }
                if let set = selectedSet {
                    SetSummaryCard(set: set, store: store).padding(.horizontal)
                }
                BigActionButton(
                    isRunning: setEngine.isRunning || isCountingDown,
                    startLabel: "Run Set",
                    stopLabel: "Stop",
                    onStart: onStart,
                    onStop: onStop
                )
                .padding(.horizontal)
                .disabled(selectedSet == nil && !setEngine.isRunning)
            }
        }
    }
}

// MARK: - Set Summary Card

struct SetSummaryCard: View {
    let set: TrainingSet
    let store: ProgramStore
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Cow order").font(.caption).foregroundColor(.secondary)
            ForEach(Array(set.entries.enumerated()), id: \.element.id) { i, entry in
                HStack(spacing: 10) {
                    Text("\(i + 1)")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.white)
                        .frame(width: 22, height: 22)
                        .background(Color.orange)
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 1) {
                        Text(store.run(for: entry.runID)?.name ?? "Unknown")
                            .font(.subheadline.weight(.medium))
                        if i < set.entries.count - 1 {
                            Text("Rest \(Int(entry.restDuration))s before next")
                                .font(.caption).foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    if let run = store.run(for: entry.runID) {
                        Text(String(format: "%.1fs", run.totalDuration))
                            .font(.caption).foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(14)
    }
}

// MARK: - Live Cards

struct SimLiveCard: View {
    @ObservedObject var simEngine: CattleSimEngine
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Live \u{2014} Free Range", systemImage: "dot.radiowaves.left.and.right")
                    .font(.headline).foregroundColor(.orange)
                Spacer()
                // Show Wild Side badge when active
                if !simEngine.currentProfileName.isEmpty {
                    Text(simEngine.currentProfileName)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.orange)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color.orange.opacity(0.12))
                        .cornerRadius(8)
                }
            }
            Text(simEngine.currentBehaviour).font(.title3.weight(.semibold))
            Text(String(format: "Running for %.0fs", simEngine.elapsedTime))
                .font(.caption).foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
}

struct SetLiveCard: View {
    @ObservedObject var setEngine: SetEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Live \u{2014} Training Set", systemImage: "dot.radiowaves.left.and.right")
                    .font(.headline).foregroundColor(.orange)
                Spacer()
                Text("\(setEngine.currentRunIndex + 1) / \(setEngine.totalRuns)")
                    .font(.caption.weight(.semibold)).foregroundColor(.secondary)
            }

            switch setEngine.phase {
            case .running:
                VStack(alignment: .leading, spacing: 6) {
                    Text(setEngine.currentRunName).font(.title3.weight(.semibold))
                    ProgressView(value: setEngine.runProgress).accentColor(.orange)
                    Text(String(format: "%.1fs remaining", setEngine.runTimeRemaining))
                        .font(.caption).foregroundColor(.secondary)
                }

            case .resting:
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: "pause.circle.fill").foregroundColor(.blue).font(.title3)
                        Text("Resting...").font(.title3.weight(.semibold))
                    }
                    ProgressView(value: max(0, setEngine.restTimeRemaining),
                                 total: max(1, setEngine.restTimeRemaining + setEngine.restTimeRemaining * 0.01))
                        .accentColor(.blue)
                    HStack {
                        Text(String(format: "%.0fs until next cow", setEngine.restTimeRemaining))
                            .font(.caption).foregroundColor(.secondary)
                        Spacer()
                        if !setEngine.nextRunName.isEmpty {
                            Text("Next: \(setEngine.nextRunName)")
                                .font(.caption.weight(.medium)).foregroundColor(.orange)
                        }
                    }
                }

            default:
                EmptyView()
            }

            HStack(spacing: 6) {
                ForEach(0..<setEngine.totalRuns, id: \.self) { i in
                    Circle()
                        .fill(dotColor(for: i))
                        .frame(width: 10, height: 10)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }

    func dotColor(for index: Int) -> Color {
        if index < setEngine.currentRunIndex { return .green }
        if index == setEngine.currentRunIndex { return .orange }
        return Color(.systemGray4)
    }
}

struct FinishedBanner: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill").foregroundColor(.green).font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text("Set Complete!").font(.headline)
                Text("All cows finished.").font(.caption).foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.green.opacity(0.4), lineWidth: 1))
        .cornerRadius(14)
    }
}

// MARK: - Shared card components

struct ProfileCard: View {
    let profile: CattleProfile
    let isSelected: Bool
    var aggressionEmoji: String {
        switch profile.aggression { case .lazy: return "\u{1F404}"; case .medium: return "\u{1F402}"; case .hot: return "\u{1F403}" }
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
                ProfileStat(label: "Speed range",  value: "\(Int(Double(profile.minSpeed)/255*100))\u{2013}\(Int(Double(profile.maxSpeed)/255*100))%")
                ProfileStat(label: "Run duration", value: "\(String(format: "%.1f", profile.minRunDuration))\u{2013}\(String(format: "%.1f", profile.maxRunDuration))s")
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
                Text("\(set.entries.count) cows").font(.caption).foregroundColor(.secondary)
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
