import Foundation

class RunEngine: ObservableObject {
    @Published var isRunning = false
    @Published var currentStepIndex = 0
    @Published var currentRunName = ""
    @Published var progress: Double = 0
    @Published var timeRemaining: Double = 0
    @Published var elapsedTotal: Double = 0

    private var timer: Timer?
    private var stepElapsed: Double = 0
    private var steps: [RunStep] = []
    private weak var connection: ConnectionManager?

    func start(run: CarriageRun, connection: ConnectionManager) {
        self.connection = connection
        steps = run.steps
        currentRunName = run.name
        currentStepIndex = 0
        elapsedTotal = 0
        isRunning = true
        executeCurrentStep()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        connection?.stop()
    }

    private func executeCurrentStep() {
        guard currentStepIndex < steps.count else { finish(); return }
        let step = steps[currentStepIndex]
        stepElapsed = 0
        timeRemaining = step.duration
        progress = 0
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
        progress = 0
    }
}

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
        self.profile = profile
        self.connection = connection
        isRunning = true
        elapsedTime = 0
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
            targetDuration = duration
            connection?.stop()
            phaseTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
                self?.scheduleNextPhase()
            }
        } else {
            let flip = Double.random(in: 0...1) < 0.45
            let newDir: StepDirection = flip ? (lastDirection == .forward ? .backward : .forward) : lastDirection
            lastDirection = newDir
            let speed    = Int.random(in: profile.minSpeed...profile.maxSpeed)
            let duration = Double.random(in: profile.minRunDuration...profile.maxRunDuration)
            currentBehaviour = "\(newDir == .forward ? "Running forward" : "Cutting back") @ \(Int(Double(speed)/255*100))%"
            targetDuration = duration
            connection?.setSpeed(speed)
            connection?.send(newDir.rawValue)
            phaseTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
                self?.scheduleNextPhase()
            }
        }
    }
}
