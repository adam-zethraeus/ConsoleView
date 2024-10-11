import Dispatch

@globalActor
actor ConsoleActor: GlobalActor {
  final class GlobalActorSerialExecutor: SerialExecutor {
    let queue = DispatchQueue(
      label: "ConsoleActorSerialExecutor", qos: .userInitiated, attributes: []
    )

    init() {}

    func enqueue(_ job: UnownedJob) {
      let e = asUnownedSerialExecutor()
      queue.schedule {
        job.runSynchronously(on: e)
      }
    }

    func asUnownedSerialExecutor() -> UnownedSerialExecutor {
      .init(ordinary: self)
    }
  }

  static let shared = ConsoleActor()
  private static let executor = GlobalActorSerialExecutor()
  static let sharedUnownedExecutor: UnownedSerialExecutor = ConsoleActor.executor
    .asUnownedSerialExecutor()

  nonisolated var unownedExecutor: UnownedSerialExecutor {
    Self.sharedUnownedExecutor
  }
}
