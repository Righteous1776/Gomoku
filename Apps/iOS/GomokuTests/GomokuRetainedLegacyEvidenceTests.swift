import Foundation
import CryptoKit
import XCTest
@testable import Gomoku

final class GomokuRetainedLegacyEvidenceTests: XCTestCase {
    func testOwnerRawArchiveIsReadOnlyAndDigestVerified() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("GomokuRawReadOnly-" + UUID().uuidString)
        let raw = root.appendingPathComponent("RawSources")
        try FileManager.default.createDirectory(at: raw, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let payload: [String: Any] = [
            "format": "veillink.board-learning.export.v1",
            "payload": [
                "recentGames": [["game": "gomoku", "result": "unfinished"]],
                "positions": ["g:abc": ["actions": [:]]]
            ]
        ]
        let bytes = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        let sha = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
        let path = raw.appendingPathComponent(sha + ".vltrain.json")
        try bytes.write(to: path, options: .atomic)

        let sources = try GomokuRetainedLegacyEvidence.list(directory: root)
        XCTAssertEqual(sources.count, 1)
        XCTAssertEqual(sources.first?.id, sha)
        XCTAssertEqual(sources.first?.originalGameRecords, 1)
        XCTAssertEqual(sources.first?.hashedPositionEntries, 1)
        XCTAssertEqual(try Data(contentsOf: path), bytes, "List must not mutate source bytes")
        XCTAssertEqual(GomokuNativeTrainingJournal(directory: root).count(), 0,
                       "Inspection must not manufacture terminal training games")

        try Data("tampered".utf8).write(to: path, options: .atomic)
        XCTAssertThrowsError(try GomokuRetainedLegacyEvidence.list(directory: root))
    }
}
