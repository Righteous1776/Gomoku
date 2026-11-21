import Foundation

/// Serializes the short critical section between cancellation and disk commit.
/// An old worker can never append AFTER stop() has returned. A commit already
/// in progress completes before stop() returns, so its result is still owned
/// by the old session rather than silently applied to the new generation.
/// Uses no main-actor hopping for the disk write itself.
final class GomokuTrainingWriteGate: @unchecked Sendable {
    private let lock = NSLock()
    private var token: UUID?

    func begin(_ generation: UUID) {
        lock.lock()
        token = generation
        lock.unlock()
    }

    func revoke() {
        lock.lock()
        token = nil
        lock.unlock()
    }

    func isCurrent(_ generation: UUID) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return token == generation
    }

    func commit<T>(
        generation: UUID, _ operation: () throws -> T
    ) rethrows -> T? {
        lock.lock()
        defer { lock.unlock() }
        guard token == generation else { return nil }
        return try operation()
    }
}
