import CryptoKit
import Foundation
import Security

/// Provenance for genuinely played *local* Gomoku games.
///
/// User-selected JSON imports are reference archives only; their JSON content
/// cannot assert that a match was played on this device. The independent
/// learning engine trusts a final match only if it has a device-keyed HMAC
/// receipt written by the live controller *after* the archive commit.
///
/// Missing keys, lost receipts or altered match files fail closed. Neither
/// VeilLink's private sandbox nor Xiangqi is consulted.
final class GomokuLocalMatchEvidence {
    private struct Receipt: Codable {
        let schema: Int
        let sessionID: String
        let mac: Data
    }

    enum EvidenceError: Error {
        case invalidMatch, keyUnavailable
    }

    let directory: URL
    private let suppliedKey: Data?

    init(directory: URL? = nil, testingKey: Data? = nil) {
        if let directory {
            self.directory = directory
        } else {
            let support = FileManager.default.urls(
                for: .applicationSupportDirectory, in: .userDomainMask
            ).first ?? FileManager.default.temporaryDirectory
            self.directory = support.appendingPathComponent(
                "Gomoku/VerifiedLocalLearningV1", isDirectory: true
            )
        }
        self.suppliedKey = testingKey
    }

    /// Called only by the real local match lifecycle, not importMatch().
    func attestCommittedLocalMatch(_ match: VeilGomokuMatchArchive.Match) throws {
        guard match.status == .playing || match.status == .humanWon
                || match.status == .aiWon || match.status == .draw,
              match.status == .playing ? match.completedAt == nil : match.completedAt != nil,
              match.isReplayable,
              UUID(uuidString: match.id)?.uuidString == match.id else {
            throw EvidenceError.invalidMatch
        }
        let key = try signingKey(createIfMissing: true)
        let mac = try Self.mac(match, key: key)
        let receipt = Receipt(schema: 1, sessionID: match.id, mac: mac)
        try FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true
        )
        let destination = directory.appendingPathComponent(match.id + ".receipt")
        var options: Data.WritingOptions = [.atomic]
        #if canImport(UIKit)
        options.insert(.completeFileProtectionUntilFirstUserAuthentication)
        #endif
        try JSONEncoder().encode(receipt).write(to: destination, options: options)
    }

    /// No automatic promotion of untrusted historical or imported matches.
    func isVerifiedLocal(_ match: VeilGomokuMatchArchive.Match) -> Bool {
        guard match.status == .playing || match.status == .humanWon
                || match.status == .aiWon || match.status == .draw,
              match.status == .playing ? match.completedAt == nil : match.completedAt != nil,
              UUID(uuidString: match.id)?.uuidString == match.id,
              let key = try? signingKey(createIfMissing: false) else {
            return false
        }
        let path = directory.appendingPathComponent(match.id + ".receipt")
        guard let size = try? path.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              (1...4_096).contains(size),
              let bytes = try? Data(contentsOf: path),
              let receipt = try? JSONDecoder().decode(Receipt.self, from: bytes),
              receipt.schema == 1, receipt.sessionID == match.id,
              let expected = try? Self.mac(match, key: key) else {
            return false
        }
        return expected == receipt.mac
    }

    private static func mac(_ match: VeilGomokuMatchArchive.Match, key: Data) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let canonical = try encoder.encode(match)
        return Data(HMAC<SHA256>.authenticationCode(
            for: canonical, using: SymmetricKey(data: key)
        ))
    }

    private static let service = "studio.zeo.gomoku.local-match-evidence"
    private static let account = "device-hmac-v1"

    private func signingKey(createIfMissing: Bool) throws -> Data {
        if let suppliedKey, suppliedKey.count == 32 { return suppliedKey }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: Self.account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess, let bytes = result as? Data, bytes.count == 32 {
            return bytes
        }
        guard status == errSecItemNotFound, createIfMissing else {
            throw EvidenceError.keyUnavailable
        }
        var material = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, material.count, &material) == errSecSuccess else {
            throw EvidenceError.keyUnavailable
        }
        let key = Data(material)
        let request: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: Self.account,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: key
        ]
        guard SecItemAdd(request as CFDictionary, nil) == errSecSuccess else {
            // A concurrent creator may have won the race. Re-read instead of
            // overwriting or minting a mismatched signing identity.
            if SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
               let actual = result as? Data, actual.count == 32 {
                return actual
            }
            throw EvidenceError.keyUnavailable
        }
        return key
    }
}
