import Foundation
import XCTest
@testable import Gomoku

final class GomokuLegacyLearningImporterTests: XCTestCase {
    private struct Match: Codable {
        let game: String
        let result: AdaptiveBoardGameResult
        let actions: [String]
        let finishedAt: Date
    }
    private struct Payload: Codable {
        let schema: Int
        let completedGames: Int
        let sequence: Int
        let positions: [String: String]
        let recentGames: [Match]
    }
    private struct Package: Codable {
        let format: String
        let createdAt: Date
        let appVersion: String
        let checksumAlgorithm: String
        let payloadChecksum: String
        let payload: Payload
    }

    private func fnv(_ data: Data) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in data {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return String(hash, radix: 16)
    }

    private func package(in directory: URL,
                         winner: AdaptiveBoardGameResult = .humanWon,
                         checksumOverride: String? = nil) throws -> URL {
        let moves = [105, 0, 106, 1, 107, 2, 108, 3, 109]
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let gomoku = Match(
            game: "gomoku", result: winner,
            actions: moves.enumerated().map { index, move in
                (index.isMultiple(of: 2) ? "h" : "a") + String(move)
            }, finishedAt: now
        )
        let xiangqi = Match(game: "xiangqi", result: .aiWon,
                            actions: ["h64:67", "a19:22"], finishedAt: now)
        let payload = Payload(schema: 1, completedGames: 2, sequence: 2,
                              positions: [:], recentGames: [gomoku, xiangqi])
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let checksum = fnv(try encoder.encode(payload))
        let envelope = Package(
            format: "veillink.board-learning.export.v1",
            createdAt: now, appVersion: "test",
            checksumAlgorithm: "fnv1a64-canonical-json",
            payloadChecksum: checksumOverride ?? checksum, payload: payload
        )
        let path = directory.appendingPathComponent("original.vltrain.json")
        try encoder.encode(envelope).write(to: path, options: .atomic)
        return path
    }

    func testRealLegacyChecksumGomokuIsolationAndRepeatImport() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("GomokuLegacyPackage-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }
        let url = try package(in: temp)
        let target = temp.appendingPathComponent("Gomoku/ImportedLegacyLearningV1")
        let importer = GomokuLegacyLearningImporter(directory: target)
        let developerGate = GomokuDeveloperPermit()
        let permission = developerGate.grant(until: Date().addingTimeInterval(600))
        XCTAssertThrowsError(try importer.importPackage(from: url)) { error in
            guard case GomokuLegacyLearningImporter.ImportError.unauthorized = error else {
                XCTFail("No authorization must block the private training import")
                return
            }
        }
        let result = try importer.importPackage(from: url, authorization: permission)
        XCTAssertEqual(result.imported, 1)
        XCTAssertEqual(result.ignoredNonGomoku, 1)
        XCTAssertEqual(result.totalUnique, 1)
        XCTAssertEqual(GomokuNativeTrainingJournal(directory: target).count(), 1)
        let repeated = try importer.importPackage(from: url, authorization: permission)
        XCTAssertEqual(repeated.imported, 0)
        XCTAssertEqual(repeated.duplicate, 1)
        XCTAssertEqual(repeated.totalUnique, 1)
        XCTAssertNotNil(repeated.backup)
    }

    func testTamperingAndForgedWinnerCannotOverwriteExistingLearning() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("GomokuLegacySafety-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }
        let url = try package(in: temp)
        let folder = temp.appendingPathComponent("Gomoku/ImportedLegacyLearningV1")
        let importer = GomokuLegacyLearningImporter(directory: folder)
        let developerGate = GomokuDeveloperPermit()
        let permission = developerGate.grant(until: Date().addingTimeInterval(600))
        _ = try importer.importPackage(from: url, authorization: permission)
        _ = try package(in: temp, checksumOverride: "0")
        XCTAssertThrowsError(try importer.importPackage(from: url, authorization: permission))
        XCTAssertEqual(GomokuNativeTrainingJournal(directory: folder).count(), 1)
        _ = try package(in: temp, winner: .aiWon)
        XCTAssertThrowsError(try importer.importPackage(from: url, authorization: permission))
        XCTAssertEqual(GomokuNativeTrainingJournal(directory: folder).count(), 1)
    }
    func testRevokedDeveloperPermitCannotCommitPreviouslyValidatedImport() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("GomokuRevokedImport-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }
        let url = try package(in: temp)
        let destination = temp.appendingPathComponent("Gomoku/ImportedLegacyLearningV1")
        let importer = GomokuLegacyLearningImporter(directory: destination)
        let gate = GomokuDeveloperPermit()
        let permission = gate.grant(until: Date().addingTimeInterval(600))
        XCTAssertTrue(permission.isValid)
        gate.revoke()
        XCTAssertFalse(permission.isValid)
        XCTAssertThrowsError(try importer.importPackage(from: url, authorization: permission))
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
    }

}
