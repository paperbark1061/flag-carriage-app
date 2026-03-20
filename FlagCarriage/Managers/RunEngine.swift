import Foundation
import UIKit   // for haptic feedback

// MARK: - Haptics helper

struct Haptics {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}

// MARK: - Countdown Engine

class CountdownEngine: ObservableObject {
    @Published var isCountingDown = false
    @Published var count: Int = 5

    private var timer: Timer?
    private var onComplete: (() -> Void)?

    func start(then onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
        count = 5
        isCountingDown = true
        timer?.invalidate()
        Haptics.impact(.light)
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.count -= 1
            if self.count <= 0 {
                self.timer?.invalidate()
                self.isCountingDown = false
                Haptics.notification(.success)
                self.onComplete?()
            } else {
                Haptics.impact(.light)
            }
        }
    }

    func cancel() {
        timer?.invalidate()
        timer = nil
        isCountingDown = false
        count = 5
        Haptics.impact(.rigid)
    }
}

// MARK: - Run Engine

class RunEngine: ObservableObject {
    @Published var isRunning        = false
    @Published var currentStepIndex = 0
    @Published var currentRunName   = ""
    @Published var progress: Double = 0
    @Published var timeRemaining: Double = 0
    @Published var elapsedTotal: Double  = 0

    private var timer: Timer?
    private var stepElapsed: Double = 0
    private var steps: [RunStep] = []
    private weak var connection: ConnectionManager?
    var onFinish: (() -> Void)?

    func start(run: CarriageRun, connection: ConnectionManager) {
        self.connection  = connection
        steps            = run.steps
        currentRunName   = run.name
        currentStepIndex = 0
        elapsedTotal     = 0
        isRunning        = true
        executeCurrentStep()
    }

    func stop() {
        timer?.invalidate()
        timer         = nil
        isRunning     = false
        connection?.stop()
        progress      = 0
        timeRemaining = 0
    }

    private func executeCurrentStep() {
        guard currentStepIndex < steps.count else { finish(); return }
        let step = steps[currentStepIndex]
        stepElapsed   = 0
        timeRemaining = step.duration
        progress      = 0
        if step.direction != .stop { Haptics.impact(.medium) }
        connection?.setSpeed(step.speed)
        connection?.send(step.direction.rawValue)
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.stepElapsed  += 0.05
            self.elapsedTotal += 0.05
            self.progress      = min(self.stepElapsed / step.duration, 1.0)
            self.timeRemaining = max(step.duration - self.stepElapsed, 0)
            if self.stepElapsed >= step.duration {
                self.timer?.invalidate()
                self.currentStepIndex += 1
                self.executeCurrentStep()
            }
        }
    }

    private func finish() {
        isRunning        = false
        connection?.stop()
        currentStepIndex = 0
        progress         = 0
        Haptics.notification(.success)
        onFinish?()
    }
}

// MARK: - Set Engine

enum SetPhase {
    case idle
    case running(runIndex: Int)
    case resting(runIndex: Int)
    case finished
}

class SetEngine: ObservableObject {
    @Published var isRunning      = false
    @Published var phase: SetPhase = .idle
    @Published var currentRunName    = ""
    @Published var runProgress: Double = 0
    @Published var runTimeRemaining: Double = 0
    @Published var currentRunIndex   = 0
    @Published var totalRuns         = 0
    @Published var restTimeRemaining: Double = 0
    @Published var nextRunName: String = ""

    private var set: TrainingSet?
    private var store: ProgramStore?
    private weak var connection: ConnectionManager?
    private let runEngine  = RunEngine()
    private var restTimer: Timer?
    private var restElapsed: Double  = 0
    private var restDuration: Double = 0

    func start(set: TrainingSet, store: ProgramStore, connection: ConnectionManager) {
        self.set        = set
        self.store      = store
        self.connection = connection
        totalRuns       = set.entries.count
        currentRunIndex = 0
        isRunning       = true
        observeRunEngine()
        executeRun(at: 0)
    }

    func stop() {
        restTimer?.invalidate()
        restTimer = nil
        runEngine.stop()
        isRunning         = false
        phase             = .idle
        currentRunIndex   = 0
        runProgress       = 0
        restTimeRemaining = 0
        nextRunName       = ""
        Haptics.impact(.rigid)
    }

    private func executeRun(at index: Int) {
        guard let set = set, let store = store, let connection = connection else { return }
        guard index < set.entries.count else { finish(); return }

        let entry = set.entries[index]
        guard let run = store.run(for: entry.runID) else {
            executeRun(at: index + 1)
            return
        }

        currentRunIndex = index
        nextRunName     = ""
        phase           = .running(runIndex: index)
        Haptics.impact(.medium)

        runEngine.onFinish = { [weak self] in
            guard let self = self else { return }
            let restDur = set.entries[index].restDuration
            if index + 1 < set.entries.count && restDur > 0 {
                if let nextRun = store.run(for: set.entries[index + 1].runID) {
                    self.nextRunName = nextRun.name
                }
                self.startRest(duration: restDur, nextIndex: index + 1)
            } else {
                self.executeRun(at: index + 1)
            }
        }
        runEngine.start(run: run, connection: connection)
    }

    private func startRest(duration: Double, nextIndex: Int) {
        connection?.stop()
        restDuration      = duration
        restElapsed       = 0
        restTimeRemaining = duration
        phase = .resting(runIndex: nextIndex)
        Haptics.impact(.light)
        restTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.restElapsed       += 0.1
            self.restTimeRemaining  = max(self.restDuration - self.restElapsed, 0)
            if self.restElapsed >= self.restDuration {
                self.restTimer?.invalidate()
                self.restTimer = nil
                self.executeRun(at: nextIndex)
            }
        }
    }

    private func finish() {
        connection?.stop()
        isRunning = false
        phase     = .finished
        Haptics.notification(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            if case .finished = self.phase { self.phase = .idle }
        }
    }

    private func observeRunEngine() {
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] t in
            guard let self = self, self.isRunning else { t.invalidate(); return }
            DispatchQueue.main.async {
                self.runProgress      = self.runEngine.progress
                self.runTimeRemaining = self.runEngine.timeRemaining
                self.currentRunName   = self.runEngine.currentRunName
            }
        }
    }
}

// MARK: - Cattle Sim Engine

class CattleSimEngine: ObservableObject {
    @Published var isRunning         = false
    @Published var currentBehaviour  = "Idle"
    @Published var currentProfileName = ""   // shown in live card during Wild Side
    @Published var elapsedTime: Double = 0
    @Published var targetDuration: Double = 0

    // Wild Side mode — cycles randomly through all available profiles
    private var isWildSide = false
    private var allProfiles: [CattleProfile] = []
    private var wildSideTimer: Timer?        // swaps profile every 15-45s

    private var timer: Timer?
    private var phaseTimer: Timer?
    private weak var connection: ConnectionManager?
    private var profile: CattleProfile?
    private var lastDirection: StepDirection = .forward

    // Normal start — specific profile chosen
    func start(profile: CattleProfile, connection: ConnectionManager) {
        self.isWildSide  = false
        self.allProfiles = []
        self.profile     = profile
        self.connection  = connection
        currentProfileName = profile.name
        isRunning        = true
        elapsedTime      = 0
        scheduleNextPhase()
        startElapsedTimer()
    }

    // Wild Side start — rotates through all profiles at random intervals
    func startWildSide(profiles: [CattleProfile], connection: ConnectionManager) {
        guard !profiles.isEmpty else { return }
        self.isWildSide  = true
        self.allProfiles = profiles
        self.connection  = connection
        self.profile     = profiles.randomElement()
        currentProfileName = self.profile?.name ?? ""
        isRunning        = true
        elapsedTime      = 0
        scheduleNextPhase()
        startElapsedTimer()
        scheduleWildSideSwap()
    }

    func stop() {
        timer?.invalidate()
        phaseTimer?.invalidate()
        wildSideTimer?.invalidate()
        timer = nil; phaseTimer = nil; wildSideTimer = nil
        isRunning        = false
        isWildSide       = false
        connection?.stop()
        currentBehaviour = "Stopped"
        currentProfileName = ""
        Haptics.impact(.rigid)
    }

    // MARK: Private

    private func startElapsedTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.elapsedTime += 0.1
        }
    }

    // Wild Side: swap to a random (different) profile every 15-45 seconds
    private func scheduleWildSideSwap() {
        guard isWildSide, !allProfiles.isEmpty else { return }
        let interval = Double.random(in: 15...45)
        wildSideTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            guard let self = self, self.isRunning, self.isWildSide else { return }
            let others = self.allProfiles.filter { $0.id != self.profile?.id }
            if let next = (others.isEmpty ? self.allProfiles : others).randomElement() {
                self.profile = next
                DispatchQueue.main.async {
                    self.currentProfileName = next.name
                }
                Haptics.impact(.medium)
            }
            self.scheduleWildSideSwap()   // schedule the next swap
        }
    }

    private func scheduleNextPhase() {
        guard let profile = profile, isRunning else { return }
        if Double.random(in: 0...1) < profile.pauseChance {
            let duration = Double.random(in: profile.minPauseDuration...profile.maxPauseDuration)
            currentBehaviour = "Hesitating..."
            targetDuration   = duration
            connection?.stop()
            phaseTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
                self?.scheduleNextPhase()
            }
        } else {
            let flip     = Double.random(in: 0...1) < 0.45
            let newDir: StepDirection = flip ? (lastDirection == .forward ? .backward : .forward) : lastDirection
            lastDirection    = newDir
            let speed        = Int.random(in: profile.minSpeed...profile.maxSpeed)
            let duration     = Double.random(in: profile.minRunDuration...profile.maxRunDuration)
            currentBehaviour = "\(newDir == .forward ? "Moving right" : "Cutting left") @ \(Int(Double(speed)/255*100))%"
            targetDuration   = duration
            Haptics.impact(.light)
            connection?.setSpeed(speed)
            connection?.send(newDir.rawValue)
            phaseTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
                self?.scheduleNextPhase()
            }
        }
    }
}
