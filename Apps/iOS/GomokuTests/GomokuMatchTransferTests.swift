import Foundation
import XCTest
@testable import Gomoku

final class GomokuMatchTransferTests: XCTestCase {
    private func temporaryFolder() throws -> URL {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("gomoku-transfer-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
        return path
    }

    func testRoundTripPreservesMoveSequenceAndRejectsDuplicate() throws {
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let source = VeilGomokuMatchArchive(directory: folder.appendingPathComponent("source"))
        let destination = VeilGomokuMatchArchive(directory: folder.appendingPathComponent("target"))
        let session = UUID().uuidString
        var moves: [VeilGomokuMatchArchive.Move] = []
        for index in 0..<9 {
            let stone: UInt8 = index.isMultiple(of: 2) ? 1 : 2
            let position = index.isMultiple(of: 2)
                ? 7 * 15 + index / 2 : index / 2
            moves.append(.init(index: position, stone: stone))
        }
        _ = try source.save(sessionID: session, moves: moves,
                            difficulty: "balanced", humanStone: 1,
                            status: .humanWon)
        let url = try GomokuMatchTransfer(archive: source).exportMostRecent()
        defer { try? FileManager.default.removeItem(at: url) }
        let transfer = GomokuMatchTransfer(archive: destination)
        let imported = try transfer.importMatch(from: url)
        XCTAssertEqual(imported, session)
        XCTAssertEqual(try destination.read(sessionID: session)?.moves, moves)
        XCTAssertThrowsError(try transfer.importMatch(from: url))
    }

    func testInvalidJSONDoesNotAlterHistory() throws {
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let archive = VeilGomokuMatchArchive(directory: folder.appendingPathComponent("target"))
        let url = folder.appendingPathComponent("invalid.json")
        try Data("{invalid".utf8).write(to: url)
        XCTAssertThrowsError(try GomokuMatchTransfer(archive: archive).importMatch(from: url))
        XCTAssertEqual(try archive.page().totalFiles, 0)
    }
}
