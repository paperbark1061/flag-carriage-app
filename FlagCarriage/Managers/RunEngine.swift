import Foundation

// MARK: - Countdown Engine
// Shared 5-second countdown used before any run or sim starts.
// The view layer observes this and shows the overlay.

class CountdownEngine: ObservableObject {
    @Published var isCountingDown = false
    @Published var count: Int = 5

    private var timer: Timer?
    private var onComplete: (() -> Void)?

    /// Start a 5-second countdown, then call onComplete.
    func start(then onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
        count = 5
        isCountingDown = true
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.count -= 1
            if self.count <= 0 {
                self.timer?.invalidate()
                self.isCountingDown = false
                self.onComplete?()
            }
        }
    }

    func cancel() {
        timer?.invalidate()
        timer = nil
        isCountingDown = false
        count = 5
    }
}

// MARK: - Run Engine
// Plays back a single CarriageRun step by step.

class RunEngine: ObservableObject {
    @Published var isRunning       = false
    @Published var currentStepIndex = 0
    @Published var currentRunName   = ""
    @Published var progress: Double = 0
    @Published var timeRemaining: Double = 0
    @Published var elapsedTotal: Double  = 0

    private var timer: Timer?
    private var stepElapsed: Double = 0
    private var steps: [RunStep] = []
    private weak var connection: ConnectionManager?
    var onFinish: (() -> Void)?      // called when the run completes naturally

    func start(run: CarriageRun, connection: ConnectionManager) {
        self.connection = connection
        steps           = run.steps
        currentRunName  = run.name
        currentStepIndex = 0
        elapsedTotal    = 0
        isRunning       = true
        executeCurrentStep()
    }

    func stop() {
        timer?.invalidate()
        timer   = nil
        isRunning = false
        connection?.stop()
        progress  = 0
        timeRemaining = 0
    }

    private func executeCurrentStep() {
        guard currentStepIndex < steps.count else { finish(); return }
        let step = steps[currentStepIndex]
        stepElapsed   = 0
        timeRemaining = step.duration
        progress      = 0
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
        isRunning = false
        connection?.stop()
        currentStepIndex = 0
        progress         = 0
        onFinish?()
    }
}

// MARK: - Set Engine
// Plays an entire TrainingSet: runs each CarriageRun in order,
// with a configurable rest period between each one.
// Between runs the motor is stopped and a rest countdown is shown.

enum SetPhase {
    case idle
    case running(runIndex: Int)   // actively executing a run
    case resting(runIndex: Int)   // rest gap before next run
    case finished
}

class SetEngine: ObservableObject {
    @Published var isRunning      = false
    @Published var phase: SetPhase = .idle

    // Current run progress (forwarded from inner RunEngine)
    @Published var currentRunName    = ""
    @Published var runProgress: Double = 0
    @Published var runTimeRemaining: Double = 0
    @Published var currentRunIndex   = 0       // 0-based index in the set
    @Published var totalRuns         = 0

    // Rest phase
    @Published var restTimeRemaining: Double = 0

    private var set: TrainingSet?
    private var store: ProgramStore?
    private weak var connection: ConnectionManager?

    private let runEngine = RunEngine()
    private var restTimer: Timer?
    private var restElapsed: Double = 0
    private var restDuration: Double = 0

    // Forward run engine publishers
    private var runProgressToken: Any?
    private var runTimeToken: Any?
    private var runNameToken: Any?

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
        isRunning = false
        phase = .idle
        currentRunIndex = 0
        runProgress = 0
        restTimeRemaining = 0
    }

    // MARK: Private

    private func executeRun(at index: Int) {
        guard let set = set, let store = store, let connection = connection else { return }
        guard index < set.entries.count else {
            finish()
            return
        }
        let entry = set.entries[index]
        guard let run = store.run(for: entry.runID) else {
            // Skip missing run
            executeRun(at: index + 1)
            return
        }
        currentRunIndex = index
        phase = .running(runIndex: index)
        runEngine.onFinish = { [weak self] in
            guard let self = self else { return }
            let restDur = set.entries[index].restDuration
            if index + 1 < set.entries.count && restDur > 0 {
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.phase = .idle
        }
    }

    private func observeRunEngine() {
        // Poll run engine state via a timer — avoids Combine dependency
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] t in
            guard let self = self, self.isRunning else { t.invalidate(); return }
            DispatchQueue.main.async {
                self.runProgress     = self.runEngine.progress
                self.runTimeRemaining = self.runEngine.timeRemaining
                self.currentRunName  = self.runEngine.currentRunName
            }
        }
    }
}

// MARK: - Cattle Sim Engine

class CattleSimEngine: ObservableObject {
    @Published var isRunning = false
    @Published var currentBehaviour = "Idle"
    @Published var elapsedTime: Double = 0
    @Published var targetDuration: Double = 0

    private var timer: Timer?
    private var phaseTimer: Timer?
    private weak var connection: ConnectionManager?
    private var profile: CattleProfile?
    private var lastDirection: StepDirection = .forward

    func start(profile: CattleProfile, connection: ConnectionManager) {
        self.profile    = profile
        self.connection = connection
        isRunning       = true
        elapsedTime     = 0
        scheduleNextPhase()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.elapsedTime += 0.1
        }
    }

    func stop() {
        timer?.invalidate()
        phaseTimer?.invalidate()
        timer = nil; phaseTimer = nil
        isRunning = false
        connection?.stop()
        currentBehaviour = "Stopped"
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
            let flip   = Double.random(in: 0...1) < 0.45
            let newDir: StepDirection = flip ? (lastDirection == .forward ? .backward : .forward) : lastDirection
            lastDirection    = newDir
            let speed        = Int.random(in: profile.minSpeed...profile.maxSpeed)
            let duration     = Double.random(in: profile.minRunDuration...profile.maxRunDuration)
            currentBehaviour = "\(newDir == .forward ? "Running forward" : "Cutting back") @ \(Int(Double(speed)/255*100))%"
            targetDuration   = duration
            connection?.setSpeed(speed)
            connection?.send(newDir.rawValue)
            phaseTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
                self?.scheduleNextPhase()
            }
        }
    }
}
