import XCTest
@testable import Gomoku

final class EclipseThinkingHUDTests: XCTestCase {
    func testNativeStopReasonsAreRealABIAndUnknownIsNil() {
        XCTAssertEqual(
            EclipseThinkingHUDSnapshot.nativeStopReason(Int32(EG_SEARCH_REASON_FORCED_WIN)),
            "直接获胜落点 / 强制终结"
        )
        XCTAssertEqual(
            EclipseThinkingHUDSnapshot.nativeStopReason(Int32(EG_SEARCH_REASON_TIME_LIMIT)),
            "搜索预算耗尽（时间或节点）"
        )
        XCTAssertNil(EclipseThinkingHUDSnapshot.nativeStopReason(nil))
        XCTAssertNil(EclipseThinkingHUDSnapshot.nativeStopReason(-27))
    }

    func testUnsetEngineMeasurementsNeverBecomeZeroOrPercent() {
        let fixture = EclipseThinkingHUDSnapshot(
            searchID: UUID(), positionRevision: 7, context: .formal,
            isSearching: true, backend: "C++20 V2", executedModel: "2.0 Astra",
            checkpointSHA256: nil, computePolicySHA256: nil,
            elapsedMilliseconds: 1400, visitedNodes: nil,
            completedDepth: nil, stopReason: nil
        )
        XCTAssertNil(fixture.visitedNodes)
        XCTAssertNil(fixture.completedDepth)
        XCTAssertNil(fixture.averageNPS)
        XCTAssertNil(fixture.stopReason)
        XCTAssertEqual(fixture.shortStatus, "搜索中 · 阶段未提供")
        XCTAssertEqual(EclipseThinkingHUDSnapshot.version, 1)
    }

    func testRealAverageNPSNeedsValidElapsedAndNodes() {
        let fixture = EclipseThinkingHUDSnapshot(
            searchID: UUID(), positionRevision: 3, context: .formal,
            isSearching: true, backend: "Swift",
            executedModel: "1.0 Terra", checkpointSHA256: nil,
            computePolicySHA256: nil, elapsedMilliseconds: 2000,
            visitedNodes: 8000, completedDepth: 4, stopReason: nil
        )
        XCTAssertEqual(fixture.averageNPS, 4000)
        let tooEarly = EclipseThinkingHUDSnapshot(
            searchID: nil, positionRevision: 3, context: .formal,
            isSearching: true, backend: "Swift",
            executedModel: nil, checkpointSHA256: nil,
            computePolicySHA256: nil, elapsedMilliseconds: 10,
            visitedNodes: 1, completedDepth: nil, stopReason: nil
        )
        XCTAssertNil(tooEarly.averageNPS)
    }

    func testFormalCompetitionCannotLeakUncommittedCandidates() {
        XCTAssertFalse(
            EclipseThinkingHUDSnapshot.Context.formal.permitsUncommittedCandidates
        )
        XCTAssertTrue(
            EclipseThinkingHUDSnapshot.Context.teaching.permitsUncommittedCandidates
        )
        XCTAssertTrue(
            EclipseThinkingHUDSnapshot.Context.postgame.permitsUncommittedCandidates
        )
    }

    @MainActor
    func testResetClearsLastHUDAndPreventsOldRunAttribution() {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let archive = root.appendingPathComponent("archive", isDirectory: true)
        let training = root.appendingPathComponent("training", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let controller = NativeGomokuAppController(
            archiveDirectory: archive, trainingDirectory: training
        )
        controller.reset()
        let snapshot = controller.thinkingHUDSnapshot()
        XCTAssertNil(snapshot.searchID)
        XCTAssertNil(snapshot.checkpointSHA256)
        XCTAssertNil(snapshot.computePolicySHA256)
        XCTAssertNil(snapshot.stopReason)
        XCTAssertFalse(snapshot.isSearching)
        XCTAssertEqual(snapshot.positionRevision, 0)
    }
}
