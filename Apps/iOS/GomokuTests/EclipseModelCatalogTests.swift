import Foundation
import XCTest
@testable import Gomoku

@MainActor
final class EclipseModelCatalogTests: XCTestCase {

    func testModelGenerationIndependentOfComputeEffort() {
        XCTAssertEqual(EclipseModelID.featured.count, 4)
        XCTAssertEqual(EclipseModelID.featured, [.astra10, .sol10, .terra10, .luna10])
        XCTAssertEqual(Set(EclipseModelID.featured.map(\.rawValue)).count, 4)
        XCTAssertEqual(EclipseModelID.currentDefault, .terra10)
        XCTAssertEqual(EclipseModelID.astra10.name, "1.0 Astra")
        XCTAssertEqual(EclipseModelID.luna10.backend, .classicSwift)
        XCTAssertFalse(EclipseModelID.luna10.usesTrainedUnifiedSearch)
        for model in EclipseModelID.featured where model != .luna10 {
            XCTAssertTrue(model.usesTrainedUnifiedSearch)
        }
        XCTAssertNil(EclipseModelID.fromStoredIdentifier("eclipse-r29-astra"))
    }

    func testSevenOriginalNativeTiersRemainRepresentableAndReversible() {
        let expected: [BoardBotDifficulty] = [
            .relaxed, .balanced, .advanced, .master,
            .grandmaster, .legendary, .zenith
        ]
        let selected = expected.map(EclipseModelSelection.fromLegacyDifficulty)
        XCTAssertEqual(selected.map(\.legacyDifficulty), expected)
        XCTAssertEqual(selected.map(\.budgetMilliseconds),
                       [130, 260, 520, 950, 1900, 3800, 5700])
        for selection in selected {
            XCTAssertEqual(
                EclipseModelSelection.fromArchiveValue(selection.archiveValue),
                selection)
        }
        XCTAssertEqual(EclipseModelSelection.fromArchiveValue("zenith"),
                       .init(model: .astra10, compute: .extreme))
        XCTAssertEqual(EclipseModelSelection.fromArchiveValue("eclipse-1.2-astra"),
                       .init(model: .astra10, compute: .extreme))
        XCTAssertEqual(EclipseModelSelection.fromArchiveValue("eclipse-1.1-sol"),
                       .init(model: .sol10, compute: .high))
        XCTAssertNil(EclipseModelSelection.fromArchiveValue("eclipse-1.0-astra|unknown"))
    }

    func testChangingComputeAndModelChangesActualNativePolicyAndResetsGame() {
        let oldID = UserDefaults.standard.string(forKey: EclipseModelID.selectionKey)
        let oldCompute = UserDefaults.standard.string(forKey: EclipseComputeTier.selectionKey)
        defer {
            if let oldID { UserDefaults.standard.set(oldID, forKey: EclipseModelID.selectionKey) }
            else { UserDefaults.standard.removeObject(forKey: EclipseModelID.selectionKey) }
            if let oldCompute { UserDefaults.standard.set(oldCompute, forKey: EclipseComputeTier.selectionKey) }
            else { UserDefaults.standard.removeObject(forKey: EclipseComputeTier.selectionKey) }
        }
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("Eclipse-R15-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let game = NativeGomokuAppController(
            archiveDirectory: folder.appendingPathComponent("history"),
            trainingDirectory: folder.appendingPathComponent("training"))
        XCTAssertEqual(game.selectedModel, .terra10)
        XCTAssertEqual(game.computeTier, .standard)
        XCTAssertEqual(game.difficulty, .balanced)
        game.play(112)
        XCTAssertEqual(game.board[112], 1)
        game.selectModel(.astra10)
        XCTAssertEqual(game.selectedModel, .astra10)
        XCTAssertEqual(game.computeTier, .extreme)
        XCTAssertEqual(game.difficulty, .zenith)
        XCTAssertTrue(game.board.allSatisfy { $0 == 0 })
        game.selectComputeTier(.high)
        XCTAssertEqual(game.selectedModel, .astra10)
        XCTAssertEqual(game.difficulty, .legendary)
        XCTAssertEqual(game.currentModelSelection.budgetMilliseconds, 3800)
        game.selectModel(.luna10)
        XCTAssertFalse(game.selectedModel.usesTrainedUnifiedSearch)
        XCTAssertEqual(game.difficulty, .relaxed)
    }

    func testArchiveRecoversVersionAndComputeWithoutRewritingOriginalBytes() throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("Eclipse-R15-Recover-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let archive = VeilGomokuMatchArchive(
            directory: folder.appendingPathComponent("history"))
        let gameID = UUID().uuidString
        let moves = [
            VeilGomokuMatchArchive.Move(index: 112, stone: 1),
            VeilGomokuMatchArchive.Move(index: 97, stone: 2)
        ]
        let selection = EclipseModelSelection(model: .astra10, compute: .high)
        _ = try archive.save(sessionID: gameID, moves: moves,
                             difficulty: selection.archiveValue,
                             humanStone: 1, status: .playing)
        let resumed = NativeGomokuAppController(
            archiveDirectory: archive.directory,
            trainingDirectory: folder.appendingPathComponent("training"))
        XCTAssertTrue(resumed.restoreLastPlayingSession())
        XCTAssertEqual(resumed.selectedModel, .astra10)
        XCTAssertEqual(resumed.computeTier, .high)
        XCTAssertEqual(resumed.difficulty, .legendary)
        XCTAssertEqual(try archive.read(sessionID: gameID)?.difficulty,
                       selection.archiveValue)
    }
}
