import OSLog
import SwiftUI

public struct ConsoleView: View {
  static func processTime() -> Double {
    var kinfo = kinfo_proc()
    var size = MemoryLayout<kinfo_proc>.stride
    var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
    sysctl(&mib, u_int(mib.count), &kinfo, &size, nil, 0)
    let start_time = kinfo.kp_proc.p_starttime
    let processTimeMilliseconds =
      Double(Int64(start_time.tv_sec) * 1000) + Double(start_time.tv_usec) / 1000.0
    return processTimeMilliseconds / 1000
  }

  var subsystem: String
  var since: Date

  public init(
    subsystem: String = Bundle.main.bundleIdentifier ?? "",
    since: Date? = nil
  ) {
    self.subsystem = subsystem
    self.since = since ?? Date().addingTimeInterval(-Self.processTime())
  }

  @State private var logMessages: [Logger.LogEntry] = []
  private var isLoading: Bool {
    currentTask != nil
  }

  @State private var currentTask: Task<Void, any Error>?
  @GestureState private var touch = CGSize.zero
  @State private var highlight: Set<Int> = []
  public var body: some View {
    List {
      ForEach(logMessages.enumeratedIdentifiable()) { entry in
        VStack(alignment: .leading) {
          Text(entry.value.composedMessage.prefix(100))
            .font(.caption)
            .lineLimit(3)
            .allowsTightening(true)
            .minimumScaleFactor(0.5)
            .padding(.top, 4)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
          Rectangle().fill(.clear)
            .allowsHitTesting(true)
            .frame(minWidth: 0, minHeight: 0)
          detailsBuilder(for: entry.value)
            .font(.custom("SFMono-Regular", size: 8))
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.bottom, 4)
        }
        .padding(.leading, 10)
        .padding(.trailing, 64)
        .background {
          rowBackground(log: entry.value, imageOpacity: highlight.contains(entry.id) ? 1 : 0.1)
        }
        .simultaneousGesture(
          DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .updating(
              $touch,
              body: { _, _, _ in
                highlight.insert(entry.id)
              }
            )
            .onEnded { _ in
              highlight.remove(entry.id)
            }
        )
      }
      .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
    }
    .toolbar {
      #if os(macOS)
        ShareLink(
          items: export()
        )
        .disabled(isLoading)
      #elseif os(iOS)
        ToolbarItem(placement: .navigationBarTrailing) {
          ShareLink(
            items: export()
          )
          .disabled(isLoading)
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

  @ViewBuilder func rowBackground(log: Logger.LogEntry, imageOpacity: Double = 1) -> some View {
    HStack {
      Rectangle()
        .fill(log.level.color)
        .frame(width: 6)
      Spacer().frame(minHeight: 0)
      VStack {
        if let image = Image(
          hashing: log.composedMessage,
          size: 8,
          scale: 8
        ) {
          image
            .resizable(resizingMode: .tile)
            .antialiased(false)
            .frame(maxHeight: .infinity)
            .opacity(imageOpacity)
        }
      }
      .frame(width: 64)
    }
  }

  func export() -> [String] {
    let appName: String = {
      if let displayName: String = Bundle.main.infoDictionary?["CFBundleDisplayName"]
        as? String
      {
        return displayName
      } else if let name: String = Bundle.main.infoDictionary?["CFBundleName"] as? String {
        return name
      }
      return "Application"
    }()

    return [
      ["# \(appName) Logs"],
      ["## \(logMessages.first?.date.ISO8601Format() ?? "")\n\n"],
      logMessages.map {
        "\($0.level.unicodeIcon) \($0.date.ISO8601Format()) \($0.message)\n\n"
      },
    ].flatMap { $0 }
  }

  @ViewBuilder
  func detailsBuilder(for entry: Logger.LogEntry) -> some View {
    InlineRows(alignment: .leading) {
      if entry.message.count > 100 {
        HStack {
          Text(
            "\(entry.message[entry.message.index(entry.message.startIndex, offsetBy: 100) ..< entry.message.endIndex])"
          )
          Spacer()
        }.padding(.bottom, 4)
      }
      if case let .osLog(date, level, sender, subsystem, _) = entry {
        Text("\(entry.level.icon)").foregroundStyle(level.color)
          + Text("\u{00a0}\(level)").foregroundStyle(level.color)
        Text("\(Image(systemName: "clock"))\u{00a0}\(date, style: .time)")
        Text("\(Image(systemName: "building.columns"))\u{00a0}\(sender)")
        Text("\(Image(systemName: "app.badge"))\u{00a0}\(subsystem)")
      } else {
        Text("???").foregroundStyle(entry.level.color)
          + Text("\u{00a0}\(entry.date, style: .time)")
          + Text("\u{00a0}\(entry.message)")
      }
    }
  }

  @MainActor func fetchLogs() {
    currentTask?.cancel()
    currentTask = Task { @ConsoleActor in
      let it = try await getLogs()
      if Task.isCancelled { return }
      Task { @MainActor [it] in
        self.logMessages = it
        self.currentTask = nil
      }
    }
  }

  @ConsoleActor
  func getLogs() async throws -> [Logger.LogEntry] {
    let store = try OSLogStore(scope: .currentProcessIdentifier)
    let position = store.position(date: since)
    let predicate = NSPredicate(format: "subsystem BEGINSWITH %@", subsystem)
    let entries = try store.getEntries(
      at: position,
      matching: predicate
    )

    var logs: [Logger.LogEntry] = []
    for entry in entries {
      if Task.isCancelled {
        return logs
      }
      if let entry = entry as? OSLogEntryLog {
        logs.append(
          Logger.LogEntry.osLog(
            entry.date, level: .init(entry.level), sender: entry.sender, subsystem: entry.subsystem,
            message: entry.composedMessage
          ))
      } else {
        logs.append(Logger.LogEntry.other(entry.date, message: entry.composedMessage))
      }
    }
    return logs
  }
}

extension Logger {
  enum LogEntry: Sendable, Codable {
    enum Level: String, Codable, Sendable {
      init(_ level: OSLogEntryLog.Level) {
        switch level {
        case .undefined:
          self = .undefined
        case .debug:
          self = .debug
        case .info:
          self = .info
        case .notice:
          self = .notice
        case .error:
          self = .error
        case .fault:
          self = .fault
        @unknown default:
          self = .unknown
        }
      }

      case undefined
      case debug
      case info
      case notice
      case error
      case fault
      case unknown
    }

    case osLog(Date, level: Level, sender: String, subsystem: String, message: String)
    case other(Date, message: String)

    var composedMessage: String {
      switch self {
      case let .osLog(_, _, _, _, message):
        message
      case let .other(_, message):
        message
      }
    }

    var date: Date {
      switch self {
      case let .osLog(date, _, _, _, _):
        date
      case let .other(date, _):
        date
      }
    }

    var level: Level {
      switch self {
      case .osLog(_, let level, _, _, _): level
      case .other: .undefined
      }
    }

    var sender: String? {
      switch self {
      case .osLog(_, _, let sender, _, _): sender
      case .other: nil
      }
    }

    var subsystem: String? {
      switch self {
      case let .osLog(_, _, _, subsystem, _): subsystem
      case .other: nil
      }
    }

    var message: String {
      switch self {
      case .osLog(_, _, _, _, let message): message
      case .other(_, let message): message
      }
    }
  }
}

extension Logger.LogEntry.Level {
  var color: Color {
    let color =
      switch self {
      case .debug:
        #colorLiteral(red: 0.6802735352, green: 0.852355719, blue: 0.9686274529, alpha: 1)
      case .info:
        #colorLiteral(red: 0.1960784346, green: 0.3411764801, blue: 0.1019607857, alpha: 1)
      case .notice:
        #colorLiteral(red: 0.9529411793, green: 0.6862745285, blue: 0.1333333403, alpha: 1)
      case .error:
        #colorLiteral(red: 0.9254902005, green: 0.2352941185, blue: 0.1019607857, alpha: 1)
      case .fault:
        #colorLiteral(red: 0.8655812809, green: 0.09536065043, blue: 0.09536065043, alpha: 1)
      case .undefined:
        #colorLiteral(red: 0.5568627715, green: 0.3529411852, blue: 0.9686274529, alpha: 1)
      default:
        #colorLiteral(red: 0.2549019754, green: 0.2745098174, blue: 0.3019607961, alpha: 1)
      }
    return color.swiftUIColor
  }

  var unicodeIcon: String {
    switch self {
    case .undefined: "☉"
    case .notice: "▷"
    case .debug: "✳︎"
    case .info: "i"
    case .error: "!"
    case .fault: "‼"
    case .unknown: "unknown"
    }
  }

  var label: String {
    switch self {
    case .undefined: "undefined"
    case .notice: "notice"
    case .debug: "debug"
    case .info: "info"
    case .error: "error"
    case .fault: "fault"
    case .unknown: "unknown"
    }
  }

  var icon: Image {
    switch self {
    case .undefined: Image(systemName: "exclamationmark.questionmark")
    case .notice: Image(systemName: "bell.square.fill")
    case .debug: Image(systemName: "stethoscope")
    case .info: Image(systemName: "info.square")
    case .error: Image(systemName: "exclamationmark.2")
    case .fault: Image(systemName: "exclamationmark.3")
    default: Image(systemName: "bell.square.fill")
    }
  }
}

#Preview {
  ConsoleView()
}

private struct IdentifiableBox<Value, ID: Hashable>: Identifiable {
  var value: Value
  let id: ID

  @inlinable
  init(_ value: Value, id keyPath: KeyPath<Value, ID>) {
    self.value = value
    id = value[keyPath: keyPath]
  }

  @inlinable
  init(_ value: Value, id: ID) {
    self.value = value
    self.id = id
  }
}

extension Collection {
  fileprivate func enumeratedIdentifiable() -> [IdentifiableBox<Element, Int>] {
    enumerated().map { IdentifiableBox($0.element, id: $0.offset) }
  }
}
