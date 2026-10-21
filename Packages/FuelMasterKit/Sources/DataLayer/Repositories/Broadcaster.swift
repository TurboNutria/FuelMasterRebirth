import Foundation

/// Fans a value out to every open `AsyncStream`. Used for the repositories' `changes()` streams.
actor Broadcaster<Value: Sendable> {
    private var continuations: [UUID: AsyncStream<Value>.Continuation] = [:]

    func stream() -> AsyncStream<Value> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<Value>.makeStream(bufferingPolicy: .bufferingNewest(1))
        continuations[id] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { await self?.remove(id) }
        }
        return stream
    }

    func send(_ value: Value) {
        for continuation in continuations.values { continuation.yield(value) }
    }

    private func remove(_ id: UUID) {
        continuations[id] = nil
    }
}
