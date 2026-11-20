import Foundation
import Synchronization

/// Fans a value out to every open `AsyncStream`. Used for the repositories' `changes()` streams.
/// `send` is synchronous, so a repository can publish inside the same critical section as the
/// write: observers then see changes in the order they were made.
final class Broadcaster<Value: Sendable>: Sendable {
    private let continuations = Mutex<[UUID: AsyncStream<Value>.Continuation]>([:])

    func stream() -> AsyncStream<Value> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<Value>.makeStream(bufferingPolicy: .bufferingNewest(1))
        continuation.onTermination = { [weak self] _ in
            self?.continuations.withLock { $0[id] = nil }
        }
        continuations.withLock { $0[id] = continuation }
        return stream
    }

    func send(_ value: Value) {
        continuations.withLock { continuations in
            for continuation in continuations.values { continuation.yield(value) }
        }
    }
}
