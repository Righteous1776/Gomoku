import Foundation
import XCTest
@testable import Gomoku

@MainActor
final class GomokuDeveloperFormationTests: XCTestCase {
    private let signingKey = Data(repeating: 0x4B, count: 32)

    private func path() throws -> URL {
        // Simulator runner temporary folders may be cleaned while file
        // protection / Keychain operations are running. Use an explicitly
        // allocated per-test Application Support directory instead.
        let root = (FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory)
            .appendingPathComponent("GomokuLessonTests-" + UUID().uuidString,
                                    isDirectory: true)
        try FileManager.default.createDirectory(
            at: root, withIntermediateDirectories: true
        )
        return root.appendingPathComponent("gomoku-v1.json")
    }

    func testOnlyAuthorizedValidatedLessonsCanEnterSignedRepertoire() throws {
        let file = try path()
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        let store = GomokuDeveloperLessonLibrary(fileURL: file, testingKey: signingKey)
        let valid: [GomokuDeveloperLessonLibrary.Move] = [
            .init(index: 112, stone: 1),
            .init(index: 111, stone: 2)
        ]
        XCTAssertThrowsError(try store.capture(
            name: "中心封堵", purpose: "观察基本方向", objective: "训练应手",
            moves: valid, authorized: false
        ))
        XCTAssertTrue(store.lessons.isEmpty)
        XCTAssertThrowsError(try store.capture(
            name: "中心封堵", purpose: "观察基本方向", objective: "训练应手",
            moves: [.init(index: 112, stone: 1), .init(index: 112, stone: 2)],
            authorized: true
        ))
        try store.capture(
            name: "中心封堵", purpose: "观察基本方向", objective: "训练应手",
            moves: valid, authorized: true
        )
        XCTAssertEqual(store.lessons.count, 1)
        let restarted = GomokuDeveloperLessonLibrary(fileURL: file, testingKey: signingKey)
        XCTAssertFalse(restarted.requiresRecovery)
        XCTAssertEqual(restarted.lessons.count, 1)
        let influence = restarted.influence(for: [valid[0]], aiStone: 2)
        XCTAssertEqual(influence.rootAdjustments["111"], 1_400)
        XCTAssertEqual(influence.matchedLessonNames, ["中心封堵"])
        XCTAssertTrue(restarted.influence(for: [valid[0]], aiStone: 1).matchedLessonNames.isEmpty)
    }

    func testTamperingLocksReadOnlyAndPreservesDamagedOriginal() throws {
        let file = try path()
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        let writer = GomokuDeveloperLessonLibrary(fileURL: file, testingKey: signingKey)
        try writer.capture(
            name: "防线突破", purpose: "测试签名是否防篡改", objective: "保留原始字节",
            moves: [.init(index: 112, stone: 1), .init(index: 111, stone: 2)],
            authorized: true
        )
        let original = try Data(contentsOf: file)
        var text = try XCTUnwrap(String(data: original, encoding: .utf8))
        XCTAssertTrue(text.contains("防线突破"))
        text = text.replacingOccurrences(of: "防线突破", with: "伪造阵法")
        let corrupt = Data(text.utf8)
        try corrupt.write(to: file, options: .atomic)
        let reader = GomokuDeveloperLessonLibrary(fileURL: file, testingKey: signingKey)
        XCTAssertTrue(reader.requiresRecovery)
        XCTAssertTrue(reader.lessons.isEmpty)
        XCTAssertThrowsError(try reader.capture(
            name: "其他阵法", purpose: "不应覆盖损坏文件", objective: "保护证据",
            moves: [.init(index: 112, stone: 1), .init(index: 111, stone: 2)],
            authorized: true
        ))
        XCTAssertEqual(try Data(contentsOf: file), corrupt)
    }
}
