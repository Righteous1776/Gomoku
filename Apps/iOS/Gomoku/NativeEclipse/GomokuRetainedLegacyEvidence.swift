import Foundation
import CryptoKit

/// Read-only view of the *original bytes* kept by the developer-authorized
/// VeilLink importer. No history is promoted into ECLIPSE learning here.
enum GomokuRetainedLegacyEvidence {
    struct Source: Identifiable, Sendable {
        let id: String                 // SHA256 of original envelope
        let url: URL                   // original file in protected RawSources
        let byteCount: Int
        let originalGameRecords: Int   // not necessarily legal terminal games
        let hashedPositionEntries: Int // not replayable training evidence
    }

    enum EvidenceError: LocalizedError {
        case corruptSource(String)
        var errorDescription: String? {
            switch self {
            case .corruptSource(let file):
                return "原始训练存档校验失败（\(file)）。已保留现有文件，禁止导出或训练。"
            }
        }
    }

    static func list(directory: URL = GomokuLegacyLearningImporter().directory) throws -> [Source] {
        let raw = directory.appendingPathComponent("RawSources", isDirectory: true)
        let manager = FileManager.default
        guard manager.fileExists(atPath: raw.path) else { return [] }
        let urls = try manager.contentsOfDirectory(
            at: raw,
            includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        )
        var sources: [Source] = []
        for url in urls.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            let filename = url.lastPathComponent
            let suffix = ".vltrain.json"
            let expected = String(filename.dropLast(suffix.count))
            let attributes = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            guard filename.hasSuffix(suffix), expected.count == 64,
                  expected.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }),
                  attributes.isRegularFile == true, attributes.isSymbolicLink != true else {
                throw EvidenceError.corruptSource(filename)
            }
            let bytes = try Data(contentsOf: url, options: .mappedIfSafe)
            let actual = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
            guard actual == expected,
                  let object = try? JSONSerialization.jsonObject(with: bytes) as? [String: Any],
                  object["format"] as? String == "veillink.board-learning.export.v1",
                  let payload = object["payload"] as? [String: Any],
                  let games = payload["recentGames"] as? [Any],
                  let positions = payload["positions"] as? [String: Any] else {
                throw EvidenceError.corruptSource(filename)
            }
            sources.append(Source(
                id: expected, url: url, byteCount: bytes.count,
                originalGameRecords: games.count, hashedPositionEntries: positions.count
            ))
        }
        return sources
    }
}
