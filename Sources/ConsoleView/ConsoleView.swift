import SwiftUI
import OSLog

public struct ConsoleView: View {
    public var subsystem: String
    public var since: Date

    public init(
        subsystem: String = Bundle.main.bundleIdentifier ?? "",
        since: Date = Date().addingTimeInterval(-3600)
    ) {
        self.subsystem = subsystem
        self.since = since
    }

    @State private var logMessages: [OSLogEntryLog] = []
  private var isLoading: Bool {
    currentTask != nil
  }
  @State private var currentTask: Task<(), any Error>?
    public var body: some View {
        VStack {
            List {
                ForEach(logMessages, id: \.self) { entry in
                    VStack {
                        Text(entry.composedMessage)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        detailsBuilder(for: entry)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .font(.footnote)
                    }
                    .listRowBackground(getBackgroundColor(level: entry.level))
                }
            }
        }
        .toolbar {
#if os(macOS)
                ShareLink(
                    items: export()
                )
                .disabled(!logMessages.isEmpty)
#elseif os(iOS)
            ToolbarItem(placement: .navigationBarTrailing) {
                    ShareLink(
                        items: export()
                    )
                    .disabled(!logMessages.isEmpty)
            }
#endif
        }
        .overlay {
            if logMessages.isEmpty {
                if isLoading {
                        ContentUnavailableView("Collecting logs...", systemImage: "hourglass")
                } else {
                        ContentUnavailableView(
                            "No results found",
                            systemImage: "magnifyingglass",
                            description: Text("for subsystem \"\(subsystem)\".")
                        )
                }
            }
        }
        .refreshable {
          fetchLogs()
        }
        .task {
          fetchLogs()
        }
    }

    func export() -> [String] {
        let appName: String = {
            if let displayName: String = Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String {
                return displayName
            } else if let name: String = Bundle.main.infoDictionary?["CFBundleName"] as? String {
                return name
            }
            return "this application"
        }()

        return [
            [
                "OSLog archive for \(appName)\n",
                logMessages.map {
                    "\($0.composedMessage)\n" +
                    getLogLevelEmoji(level: $0.level) +
                    " \($0.date.formatted()) 🏛️ \($0.sender) ⚙️ \($0.subsystem) 🌐 \($0.category)"
                }
                    .joined(separator: "\n")
            ]
                .joined()
        ]
    }

    @ViewBuilder
    func detailsBuilder(for entry: OSLogEntryLog) -> Text {
        getLogLevelIcon(level: entry.level) +
        Text("\u{00a0}") +
        Text(entry.date, style: .time) +
        Text(" ") +
        Text("\(Image(systemName: "building.columns"))\u{00a0}\(entry.sender) ") +
        Text("\(Image(systemName: "gearshape.2"))\u{00a0}\(entry.subsystem) ") +
        Text("\(Image(systemName: "square.grid.3x3"))\u{00a0}\(entry.category)")
    }

    func getLogLevelEmoji(level: OSLogEntryLog.Level) -> String {
        switch level {
        case .undefined, .notice:
            "🔔"
        case .debug:
            "🩺"
        case .info:
            "ℹ️"
        case .error:
            "❗"
        case .fault:
            "‼️"
        default:
            "🔔"
        }
    }

    func getLogLevelIcon(level: OSLogEntryLog.Level) -> Text {
        switch level {
        case .undefined, .notice:
            Text(Image(systemName: "bell.square.fill"))
                .accessibilityLabel("Notice")
        case .debug:
            Text(Image(systemName: "stethoscope"))
                .accessibilityLabel("Debug")
        case .info:
            Text(Image(systemName: "info.square"))
                .accessibilityLabel("Information")
        case .error:
            Text(Image(systemName: "exclamationmark.2"))
                .accessibilityLabel("Error")
        case .fault:
            Text(Image(systemName: "exclamationmark.3"))
                .accessibilityLabel("Fault")
        default:
            Text(Image(systemName: "bell.square.fill"))
                .accessibilityLabel("Default")
        }
    }

  @MainActor public func fetchLogs() {
    currentTask = Task { @SecondaryActor in
      let it = try await getLogs()
      Task { @MainActor [it] in
        self.logMessages = it
        self.currentTask = nil
      }
    }
  }

  @SecondaryActor
  func getLogs() async throws -> [OSLogEntryLog] {
          let logStore = try OSLogStore(scope: .currentProcessIdentifier)
          let sinceDate = logStore.position(date: since)
          let predicate = NSPredicate(format: "subsystem BEGINSWITH %@", subsystem)
        let logs = try logStore.getEntries(at: sinceDate, matching: predicate)
    return logs.compactMap { $0 as? OSLogEntryLog }
    }
}

#Preview {
        ConsoleView()
}

extension OSLogEntryLog: @unchecked Sendable {}
