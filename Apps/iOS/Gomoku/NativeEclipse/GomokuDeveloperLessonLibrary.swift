import CryptoKit
import Foundation
import Security

/// A Gomoku-only adaptation of VeilLink's signed developer lesson library.
/// Does not import a messenger owner-mode token, account, or Xiangqi knowledge.
@MainActor
final class GomokuDeveloperLessonLibrary {
    struct Move: Codable, Equatable, Sendable {
        let index: Int
        let stone: UInt8
    }

    struct Lesson: Codable, Equatable, Identifiable, Sendable {
        let id: UUID
        let name: String
        let purpose: String
        let objective: String
        let moves: [Move]
        let createdAt: Date
    }

    private struct Envelope: Codable {
        let schema: Int
        let lessons: [Lesson]
        let mac: Data
    }

    enum LibraryError: LocalizedError {
        case unauthorized, invalidLesson, keyUnavailable, damagedStore
        var errorDescription: String? {
            switch self {
            case .unauthorized: return "开发者授权已失效；拒绝修改私有阵法数据库。"
            case .invalidLesson: return "请提供完整名称、用途、目标和合法的黑白双方攻防棋谱。"
            case .keyUnavailable: return "无法取得或保存本设备的阵法签名密钥。"
            case .damagedStore: return "本地阵法文件或签名无法验证，已进入只读保护。"
            }
        }
    }

    private let fileURL: URL
    // In production this is always nil; DEBUG-only test instances use a
    // per-test isolated key instead of an unavailable unsigned-simulator Keychain.
    private let testSigningKey: Data?
    private(set) var lessons: [Lesson] = []
    private(set) var requiresRecovery = false

    init(fileURL: URL? = nil) {
        self.testSigningKey = nil
        if let fileURL { self.fileURL = fileURL }
        else {
            let root = FileManager.default.urls(
                for: .applicationSupportDirectory, in: .userDomainMask
            ).first ?? FileManager.default.temporaryDirectory
            self.fileURL = root.appendingPathComponent("Gomoku/DeveloperFormations/gomoku-v1.json")
        }
        load()
    }

    #if DEBUG
    // TEST ONLY: no fallback to a known key for production-created stores.
    // The entire initializer is absent from Release builds.
    init(testFileURL: URL, testSigningKey: Data) {
        precondition(testSigningKey.count == 32)
        self.fileURL = testFileURL
        self.testSigningKey = testSigningKey
        load()
    }
    #endif

    private func valid(_ candidate: Lesson) -> Bool {
        guard (2...64).contains(candidate.name.count),
              (2...360).contains(candidate.purpose.count),
              (2...240).contains(candidate.objective.count),
              (2...225).contains(candidate.moves.count),
              candidate.moves.contains(where: { $0.stone == 2 }) else { return false }
        var board = GomokuState()
        for move in candidate.moves {
            let stone: UInt8 = board.currentPlayer == .host ? 1 : 2
            guard move.stone == stone,
                  board.apply(index: move.index, actor: board.currentPlayer) else { return false }
        }
        return true
    }

    func capture(
        name: String, purpose: String, objective: String,
        moves: [Move], authorized: Bool
    ) throws {
        guard authorized else { throw LibraryError.unauthorized }
        guard !requiresRecovery else { throw LibraryError.damagedStore }
        let lesson = Lesson(
            id: UUID(), name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            purpose: purpose.trimmingCharacters(in: .whitespacesAndNewlines),
            objective: objective.trimmingCharacters(in: .whitespacesAndNewlines),
            moves: moves, createdAt: Date()
        )
        guard valid(lesson) else { throw LibraryError.invalidLesson }
        let previous = lessons
        lessons.append(lesson)
        do { try save() }
        catch { lessons = previous; throw error }
    }

    func remove(id: UUID, authorized: Bool) throws {
        guard authorized else { throw LibraryError.unauthorized }
        guard !requiresRecovery else { throw LibraryError.damagedStore }
        let previous = lessons
        lessons.removeAll { $0.id == id }
        do { try save() }
        catch { lessons = previous; throw error }
    }

    func influence(
        for current: [Move], aiStone: UInt8
    ) -> DeveloperFormationInfluence {
        guard !requiresRecovery, (1...2).contains(aiStone) else { return .empty }
        var roots: [String: Int] = [:]
        var replies: [String: AdaptiveBoardPrediction] = [:]
        var names: [String] = []
        for lesson in lessons where lesson.moves.starts(with: current) {
            guard current.count < lesson.moves.count else { continue }
            let next = lesson.moves[current.count]
            guard next.stone == aiStone else { continue }
            let action = String(next.index)
            names.append(lesson.name)
            roots[action, default: 0] += 1_400
            let replyOffset = current.count + 1
            if replyOffset < lesson.moves.count,
               lesson.moves[replyOffset].stone != aiStone {
                replies[action] = AdaptiveBoardPrediction(
                    action: String(lesson.moves[replyOffset].index),
                    evidence: 99
                )
            }
        }
        return DeveloperFormationInfluence(
            rootAdjustments: roots, predictedHumanReplies: replies,
            matchedLessonNames: names.sorted()
        )
    }

    private func save() throws {
        guard !requiresRecovery else { throw LibraryError.damagedStore }
        let key = try signingKey(createIfMissing: true)
        let code = Data(HMAC<SHA256>.authenticationCode(
            for: try Self.canonical(lessons), using: SymmetricKey(data: key)
        ))
        let bytes = try JSONEncoder().encode(Envelope(schema: 1, lessons: lessons, mac: code))
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        var options: Data.WritingOptions = [.atomic]
        #if canImport(UIKit)
        options.insert(.completeFileProtectionUntilFirstUserAuthentication)
        #endif
        try bytes.write(to: fileURL, options: options)
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let bytes = try Data(contentsOf: fileURL)
            let envelope = try JSONDecoder().decode(Envelope.self, from: bytes)
            guard envelope.schema == 1,
                  Set(envelope.lessons.map(\.id)).count == envelope.lessons.count,
                  envelope.lessons.allSatisfy({ valid($0) }) else {
                requiresRecovery = true
                return
            }
            let key = try signingKey(createIfMissing: false)
            let calculated = Data(HMAC<SHA256>.authenticationCode(
                for: try Self.canonical(envelope.lessons),
                using: SymmetricKey(data: key)
            ))
            guard calculated == envelope.mac else {
                requiresRecovery = true
                return
            }
            lessons = envelope.lessons
        } catch {
            requiresRecovery = true
        }
    }

    private static func canonical(_ lessons: [Lesson]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(lessons)
    }

    private func signingKey(createIfMissing: Bool) throws -> Data {
        #if DEBUG
        if let testSigningKey { return testSigningKey }
        #endif
        return try Self.macKey(createIfMissing: createIfMissing)
    }

    private static let service = "studio.zeo.gomoku.developer-formations"
    private static let keyAccount = "hmac-sha256-v1"

    private static func macKey(createIfMissing: Bool) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: keyAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess, let data = result as? Data, data.count == 32 {
            return data
        }
        guard status == errSecItemNotFound, createIfMissing else {
            throw LibraryError.keyUnavailable
        }
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            throw LibraryError.keyUnavailable
        }
        let data = Data(bytes)
        let additions: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: keyAccount,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: data
        ]
        guard SecItemAdd(additions as CFDictionary, nil) == errSecSuccess else {
            throw LibraryError.keyUnavailable
        }
        return data
    }
}
