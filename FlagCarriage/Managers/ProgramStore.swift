import Foundation

struct RunStep: Identifiable, Codable, Hashable {
    var id = UUID()
    var direction: StepDirection
    var speed: Int
    var duration: Double
    var note: String = ""
}

enum StepDirection: String, Codable, CaseIterable {
    case forward  = "F"
    case backward = "B"
    case stop     = "S"

    var label: String {
        switch self {
        case .forward:  return "Forward"
        case .backward: return "Backward"
        case .stop:     return "Hold"
        }
    }
    var icon: String {
        switch self {
        case .forward:  return "arrow.right"
        case .backward: return "arrow.left"
        case .stop:     return "pause.fill"
        }
    }
}

struct CarriageRun: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var steps: [RunStep]
    var createdAt: Date = Date()
    var totalDuration: Double { steps.reduce(0) { $0 + $1.duration } }
}

struct TrainingSet: Identifiable, Codable {
    var id = UUID()
    var name: String
    var entries: [SetEntry]
    var createdAt: Date = Date()
}

struct SetEntry: Identifiable, Codable {
    var id = UUID()
    var runID: UUID
    var restDuration: Double
}

struct CattleProfile: Identifiable, Codable {
    var id = UUID()
    var name: String
    var aggression: Aggression
    var minSpeed: Int
    var maxSpeed: Int
    var minRunDuration: Double
    var maxRunDuration: Double
    var pauseChance: Double
    var minPauseDuration: Double
    var maxPauseDuration: Double
    var changeFrequency: Double

    enum Aggression: String, Codable, CaseIterable {
        case lazy, medium, hot
        var label: String { rawValue.capitalized }
    }

    static let defaults: [CattleProfile] = [
        CattleProfile(name: "Lazy Cow", aggression: .lazy,
            minSpeed: 60, maxSpeed: 130,
            minRunDuration: 1.5, maxRunDuration: 4.0,
            pauseChance: 0.4, minPauseDuration: 0.8, maxPauseDuration: 2.5,
            changeFrequency: 3.0),
        CattleProfile(name: "Medium Cow", aggression: .medium,
            minSpeed: 100, maxSpeed: 190,
            minRunDuration: 0.8, maxRunDuration: 3.0,
            pauseChance: 0.25, minPauseDuration: 0.3, maxPauseDuration: 1.2,
            changeFrequency: 1.8),
        CattleProfile(name: "Hot Cow", aggression: .hot,
            minSpeed: 160, maxSpeed: 255,
            minRunDuration: 0.4, maxRunDuration: 1.5,
            pauseChance: 0.1, minPauseDuration: 0.2, maxPauseDuration: 0.6,
            changeFrequency: 0.9),
    ]
}

class ProgramStore: ObservableObject {
    @Published var runs: [CarriageRun] = []
    @Published var sets: [TrainingSet] = []
    @Published var cattleProfiles: [CattleProfile] = CattleProfile.defaults

    private let runsKey     = "savedRuns"
    private let setsKey     = "savedSets"
    private let profilesKey = "savedProfiles"

    init() { load() }

    func saveRun(_ run: CarriageRun) {
        if let idx = runs.firstIndex(where: { $0.id == run.id }) { runs[idx] = run }
        else { runs.append(run) }
        persist()
    }
    func deleteRun(_ run: CarriageRun) {
        runs.removeAll { $0.id == run.id }
        for i in sets.indices { sets[i].entries.removeAll { $0.runID == run.id } }
        persist()
    }
    func run(for id: UUID) -> CarriageRun? { runs.first { $0.id == id } }

    func saveSet(_ set: TrainingSet) {
        if let idx = sets.firstIndex(where: { $0.id == set.id }) { sets[idx] = set }
        else { sets.append(set) }
        persist()
    }
    func deleteSet(_ set: TrainingSet) { sets.removeAll { $0.id == set.id }; persist() }

    func saveProfile(_ profile: CattleProfile) {
        if let idx = cattleProfiles.firstIndex(where: { $0.id == profile.id }) { cattleProfiles[idx] = profile }
        else { cattleProfiles.append(profile) }
        persist()
    }

    /// Wipes all cows, sets and cattle profiles, then resets profiles to defaults.
    func eraseAllData() {
        runs           = []
        sets           = []
        cattleProfiles = CattleProfile.defaults
        UserDefaults.standard.removeObject(forKey: runsKey)
        UserDefaults.standard.removeObject(forKey: setsKey)
        UserDefaults.standard.removeObject(forKey: profilesKey)
    }

    private func persist() {
        if let d = try? JSONEncoder().encode(runs)           { UserDefaults.standard.set(d, forKey: runsKey) }
        if let d = try? JSONEncoder().encode(sets)           { UserDefaults.standard.set(d, forKey: setsKey) }
        if let d = try? JSONEncoder().encode(cattleProfiles) { UserDefaults.standard.set(d, forKey: profilesKey) }
    }
    private func load() {
        if let d = UserDefaults.standard.data(forKey: runsKey),     let r = try? JSONDecoder().decode([CarriageRun].self,    from: d) { runs = r }
        if let d = UserDefaults.standard.data(forKey: setsKey),     let s = try? JSONDecoder().decode([TrainingSet].self,    from: d) { sets = s }
        if let d = UserDefaults.standard.data(forKey: profilesKey), let p = try? JSONDecoder().decode([CattleProfile].self,  from: d) { cattleProfiles = p }
        if cattleProfiles.isEmpty { cattleProfiles = CattleProfile.defaults }
    }
}
