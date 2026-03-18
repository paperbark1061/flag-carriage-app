import SwiftUI

struct ProfileEditorView: View {
    @EnvironmentObject var store: ProgramStore
    @Environment(\.dismiss) var dismiss
    let profile: CattleProfile
    @State private var name = ""
    @State private var aggression: CattleProfile.Aggression = .medium
    @State private var minSpeed: Double = 100
    @State private var maxSpeed: Double = 190
    @State private var minRunDuration: Double = 0.8
    @State private var maxRunDuration: Double = 3.0
    @State private var pauseChance: Double = 0.25
    @State private var minPauseDuration: Double = 0.3
    @State private var maxPauseDuration: Double = 1.2
    @State private var changeFrequency: Double = 1.8

    var body: some View {
        NavigationView {
            Form {
                Section("Identity") {
                    TextField("Profile name", text: $name)
                    Picker("Aggression", selection: $aggression) {
                        ForEach(CattleProfile.Aggression.allCases, id: \.self) { a in Text(a.label).tag(a) }
                    }
                }
                Section {
                    SliderRow(label: "Min speed", value: $minSpeed, range: 30...255) { "\(Int($0/255*100))%" }
                    SliderRow(label: "Max speed", value: $maxSpeed, range: 30...255) { "\(Int($0/255*100))%" }
                } header: { Text("Speed range") }
                Section {
                    SliderRow(label: "Min run", value: $minRunDuration, range: 0.2...5)  { String(format: "%.1fs", $0) }
                    SliderRow(label: "Max run", value: $maxRunDuration, range: 0.5...10) { String(format: "%.1fs", $0) }
                } header: { Text("Run duration") }
                Section {
                    SliderRow(label: "Pause chance", value: $pauseChance, range: 0...1)   { "\(Int($0*100))%" }
                    SliderRow(label: "Min pause",    value: $minPauseDuration, range: 0.1...3) { String(format: "%.1fs", $0) }
                    SliderRow(label: "Max pause",    value: $maxPauseDuration, range: 0.2...5) { String(format: "%.1fs", $0) }
                } header: { Text("Hesitation") }
                Section {
                    SliderRow(label: "Change frequency", value: $changeFrequency, range: 0.3...5) { String(format: "%.1fs", $0) }
                } header: { Text("Direction Changes") }
                footer: { Text("Lower = more unpredictable direction changes.") }
            }
            .navigationTitle("Edit Profile")
            .navigationBarItems(
                leading:  Button("Cancel") { dismiss() },
                trailing: Button("Save") { save() }.disabled(name.isEmpty)
            )
            .onAppear { loadProfile() }
        }
    }

    func loadProfile() {
        name = profile.name; aggression = profile.aggression
        minSpeed = Double(profile.minSpeed); maxSpeed = Double(profile.maxSpeed)
        minRunDuration = profile.minRunDuration; maxRunDuration = profile.maxRunDuration
        pauseChance = profile.pauseChance
        minPauseDuration = profile.minPauseDuration; maxPauseDuration = profile.maxPauseDuration
        changeFrequency = profile.changeFrequency
    }

    func save() {
        var p = profile
        p.name = name; p.aggression = aggression
        p.minSpeed = Int(minSpeed); p.maxSpeed = Int(maxSpeed)
        p.minRunDuration = minRunDuration; p.maxRunDuration = maxRunDuration
        p.pauseChance = pauseChance
        p.minPauseDuration = minPauseDuration; p.maxPauseDuration = maxPauseDuration
        p.changeFrequency = changeFrequency
        store.saveProfile(p); dismiss()
    }
}

struct SliderRow: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let displayFormat: (Double) -> String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                Spacer()
                Text(displayFormat(value)).foregroundColor(.orange).monospacedDigit()
            }
            Slider(value: $value, in: range).accentColor(.orange)
        }.padding(.vertical, 2)
    }
}
