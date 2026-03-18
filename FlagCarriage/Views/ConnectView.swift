import SwiftUI

struct ConnectView: View {
    @EnvironmentObject var connection: ConnectionManager
    @State private var showModeHelp = false

    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(connection.isConnected ? Color.green : Color.red)
                            .frame(width: 14, height: 14)
                        Text(connection.isConnected ? "Connected" : "Disconnected")
                            .font(.headline)
                        Spacer()
                        if connection.isConnected {
                            Text(connection.lastStatus.ip.isEmpty ? connection.ipAddress : connection.lastStatus.ip)
                                .font(.caption).foregroundColor(.secondary)
                        }
                    }.padding(.vertical, 4)
                } header: { Text("Status") }

                Section {
                    HStack {
                        Text("ESP IP Address")
                        Spacer()
                        TextField("192.168.4.1", text: $connection.ipAddress)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(.orange)
                    }
                    HStack {
                        Text("Port")
                        Spacer()
                        Text("81").foregroundColor(.secondary)
                    }
                } header: { Text("Network") }
                footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("AP mode (ESP hotspot): 192.168.4.1")
                        Text("STA mode (your router): check Serial Monitor")
                        Text("iPhone hotspot: check DHCP leases")
                    }.font(.caption)
                }

                Section {
                    if connection.isConnected {
                        Button(role: .destructive) {
                            connection.disconnect()
                        } label: {
                            HStack { Spacer(); Text("Disconnect").fontWeight(.semibold); Spacer() }
                        }
                    } else {
                        Button {
                            connection.connect()
                        } label: {
                            HStack {
                                Spacer()
                                Text("Connect").fontWeight(.semibold).foregroundColor(.white)
                                Spacer()
                            }.padding(.vertical, 4)
                        }.listRowBackground(Color.orange)
                    }
                }

                if let error = connection.errorMessage {
                    Section { Text(error).foregroundColor(.red).font(.caption) } header: { Text("Error") }
                }

                if connection.isConnected {
                    Section {
                        StatusRow(label: "Direction", value: directionLabel)
                        StatusRow(label: "Speed",     value: "\(Int(Double(connection.lastStatus.speed)/255*100))%")
                        StatusRow(label: "Limit A",   value: connection.lastStatus.limitA ? "TRIGGERED" : "Clear",
                                  valueColor: connection.lastStatus.limitA ? .red : .green)
                        StatusRow(label: "Limit B",   value: connection.lastStatus.limitB ? "TRIGGERED" : "Clear",
                                  valueColor: connection.lastStatus.limitB ? .red : .green)
                    } header: { Text("Live Carriage Status") }
                }

                Section {
                    DisclosureGroup("WiFi Mode Guide", isExpanded: $showModeHelp) {
                        VStack(alignment: .leading, spacing: 10) {
                            ModeHelpRow(title: "AP Mode (Hotspot)",
                                        description: "Set WIFI_MODE_AP in config.h. ESP creates FlagCarriage network. IP is always 192.168.4.1.")
                            ModeHelpRow(title: "STA Mode (Router)",
                                        description: "Set WIFI_MODE_STA with your credentials. Serial Monitor shows IP on startup.")
                            ModeHelpRow(title: "iPhone Hotspot",
                                        description: "Use STA mode with hotspot name/password. Check Settings > Personal Hotspot for the IP.")
                        }.padding(.top, 4)
                    }
                }
            }
            .navigationTitle("Connect")
        }
    }

    var directionLabel: String {
        switch connection.lastStatus.direction {
        case "F": return "Forward"
        case "B": return "Backward"
        default:  return "Stopped"
        }
    }
}

struct StatusRow: View {
    let label: String
    let value: String
    var valueColor: Color = .primary
    var body: some View {
        HStack {
            Text(label).foregroundColor(.secondary)
            Spacer()
            Text(value).foregroundColor(valueColor).fontWeight(.medium)
        }
    }
}

struct ModeHelpRow: View {
    let title: String
    let description: String
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).fontWeight(.semibold).font(.subheadline)
            Text(description).font(.caption).foregroundColor(.secondary)
        }
    }
}
