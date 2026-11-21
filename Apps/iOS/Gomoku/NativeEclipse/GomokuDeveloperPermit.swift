import Foundation

/// Revocable in-process capability for privileged imports. A copied expiry
/// Date alone is not an authorization: locking the developer lab must
/// invalidate a concurrent import even if its file validation is still running.
final class GomokuDeveloperPermit: @unchecked Sendable {
    struct Authorization: Sendable {
        fileprivate let issuer: GomokuDeveloperPermit
        fileprivate let token: UUID

        var isValid: Bool { issuer.isCurrent(token) }

        /// The commit body and revoke() are serialized by the same lock.
        /// A revoked/expired token cannot enter a subsequent write boundary.
        func commit<T>(_ body: () throws -> T) rethrows -> T? {
            try issuer.commit(token: token, body)
        }
    }

    private let lock = NSLock()
    private var token: UUID?
    private var expiresAt: Date = .distantPast

    func grant(until expiry: Date) -> Authorization {
        lock.lock()
        defer { lock.unlock() }
        let next = UUID()
        token = next
        expiresAt = expiry
        return Authorization(issuer: self, token: next)
    }

    func currentAuthorization() -> Authorization? {
        lock.lock()
        defer { lock.unlock() }
        guard let token, Date() < expiresAt else { return nil }
        return Authorization(issuer: self, token: token)
    }

    func revoke() {
        lock.lock()
        token = nil
        expiresAt = .distantPast
        lock.unlock()
    }

    private func isCurrent(_ value: UUID) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return token == value && Date() < expiresAt
    }

    private func commit<T>(token value: UUID, _ body: () throws -> T) rethrows -> T? {
        lock.lock()
        defer { lock.unlock() }
        guard token == value, Date() < expiresAt else { return nil }
        return try body()
    }
}
