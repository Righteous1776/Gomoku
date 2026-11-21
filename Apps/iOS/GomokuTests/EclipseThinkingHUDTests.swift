import XCTest
@testable import Gomoku

final class EclipseThinkingHUDTests: XCTestCase {
    func testNativeP50P95UsesRealSamePolicySamplesAndMinimumTwenty() {
        XCTAssertNil(EclipseNativeLatencyStatistics.summarize([1, 2, 3]))
        XCTAssertNil(EclipseNativeLatencyStatistics.summarize(
            [Int](repeating: 100, count: 19)
        ))
        XCTAssertNil(EclipseNativeLatencyStatistics.summarize(
            [Int](repeating: 0, count: 20)
        ))
        let measured = Array((1...20).reversed())
        let summary = EclipseNativeLatencyStatistics.summarize(measured)
        XCTAssertEqual(summary?.count, 20)
        XCTAssertEqual(summary?.p50Milliseconds, 10)
        XCTAssertEqual(summary?.p95Milliseconds, 19)
    }

    func testNativeLiveSnapshotUsesVersionedReadOnlyABI() {
        guard let engine = eg_create() else {
            XCTFail("Native engine unavailable")
            return
        }
        defer { eg_destroy(engine) }
        var snapshot = EGSearchLiveSnapshotV1()
        snapshot.size_bytes = UInt32(MemoryLayout<EGSearchLiveSnapshotV1>.size)
        XCTAssertEqual(eg_read_live_search_v1(engine, &snapshot), 1)
        XCTAssertEqual(snapshot.state, UInt32(EG_LIVE_SEARCH_IDLE))
        XCTAssertEqual(snapshot.search_serial, 0)
        XCTAssertEqual(snapshot.best_move, -1)
        XCTAssertEqual(snapshot.reason, -1)
        snapshot.size_bytes = 0
        snapshot.reason = 876
        XCTAssertEqual(eg_read_live_search_v1(engine, &snapshot), 0)
        XCTAssertEqual(snapshot.reason, 876)
    }

    func testNativeRankSnapshotIsVersionedAndEmptyWhileIdle() {
        guard let handle = eg_create() else {
            XCTFail("Native engine unavailable")
            return
        }
        defer { eg_destroy(handle) }
        var reading = EGRankedRootsSnapshotV1()
        reading.size_bytes = UInt32(MemoryLayout<EGRankedRootsSnapshotV1>.size)
        XCTAssertEqual(eg_read_ranked_roots_v1(handle, &reading), 1)
        XCTAssertEqual(reading.search_serial, 0)
        XCTAssertEqual(reading.count, 0)
        reading.size_bytes = 0
        reading.count = 999
        XCTAssertEqual(eg_read_ranked_roots_v1(handle, &reading), 0)
        XCTAssertEqual(reading.count, 999)
    }

    func testTeachingRankListRejectsFormalAndMalformedCandidates() {
        var view = EclipseThinkingHUDSnapshot(
            searchID: UUID(), positionRevision: 9, context: .formal,
            isSearching: true, backend: "C++20 V2",
            executedModel: "2.0 Astra", checkpointSHA256: nil,
            computePolicySHA256: nil, elapsedMilliseconds: 800,
            visitedNodes: 4096, completedDepth: 1, stopReason: nil
        )
        view.nativeRootRanks = [111, 112, 113]
        XCTAssertTrue(view.visibleTeachingRanks.isEmpty)
        view = EclipseThinkingHUDSnapshot(
            searchID: UUID(), positionRevision: 9, context: .teaching,
            isSearching: true, backend: "C++20 V2",
            executedModel: "2.0 Astra", checkpointSHA256: nil,
            computePolicySHA256: nil, elapsedMilliseconds: 800,
            visitedNodes: 4096, completedDepth: nil, stopReason: nil
        )
        view.nativeRootRanks = [111, 112, 113]
        XCTAssertEqual(view.visibleTeachingRanks, [111, 112, 113])
        view.nativeRootRanks = [111, 111]
        XCTAssertTrue(view.visibleTeachingRanks.isEmpty)
        view.nativeRootRanks = [225]
        XCTAssertTrue(view.visibleTeachingRanks.isEmpty)
        view.nativeRootRanks = Array(0..<17)
        XCTAssertTrue(view.visibleTeachingRanks.isEmpty)
    }

    func testNativeStopReasonsAreRealABIAndUnknownIsNil() {
        XCTAssertEqual(
            EclipseThinkingHUDSnapshot.nativeStopReason(Int32(EG_SEARCH_REASON_FORCED_WIN)),
            "直接获胜落点 / 强制终结"
        )
        XCTAssertEqual(
            EclipseThinkingHUDSnapshot.nativeStopReason(Int32(EG_SEARCH_REASON_TIME_LIMIT)),
            "搜索预算耗尽（时间或节点）"
        )
        XCTAssertEqual(
            EclipseThinkingHUDSnapshot.nativeStopReason(
                Int32(EG_SEARCH_REASON_STABLE_CONVERGENCE)),
            "低战术风险 · 连续完整深度收敛，主动结束（非必胜证明）"
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

    func testCompletedRootCandidateNeverLeaksIntoFormalOrPostgameUI() {
        var formal = EclipseThinkingHUDSnapshot(
            searchID: UUID(), positionRevision: 12, context: .formal,
            isSearching: true, backend: "C++20 V2",
            executedModel: "2.0 Astra", checkpointSHA256: nil,
            computePolicySHA256: nil, elapsedMilliseconds: 2100,
            visitedNodes: 4800, completedDepth: 3, stopReason: nil
        )
        formal.verifiedTeachingCandidate = 112 // malicious fixture
        formal.nativeRootRanks = [112, 113, 98]
        formal.nativeCompletedPV = [112, 113, 98]
        XCTAssertNil(formal.visibleTeachingCandidate)
        XCTAssertTrue(formal.visibleTeachingRanks.isEmpty)
        XCTAssertTrue(formal.visibleTeachingPV.isEmpty)

        var teaching = EclipseThinkingHUDSnapshot(
            searchID: UUID(), positionRevision: 12, context: .teaching,
            isSearching: true, backend: "C++20 V2",
            executedModel: "2.0 Astra", checkpointSHA256: nil,
            computePolicySHA256: nil, elapsedMilliseconds: 2100,
            visitedNodes: 4800, completedDepth: nil, stopReason: nil
        )
        teaching.verifiedTeachingCandidate = 112
        teaching.nativeRootRanks = [112, 113, 98]
        XCTAssertEqual(teaching.visibleTeachingRanks, [112, 113, 98])
        XCTAssertNil(teaching.visibleTeachingCandidate) // depth not completed
        teaching = EclipseThinkingHUDSnapshot(
            searchID: UUID(), positionRevision: 12, context: .teaching,
            isSearching: true, backend: "C++20 V2",
            executedModel: "2.0 Astra", checkpointSHA256: nil,
            computePolicySHA256: nil, elapsedMilliseconds: 2100,
            visitedNodes: 4800, completedDepth: 3, stopReason: nil
        )
        teaching.verifiedTeachingCandidate = 112
        teaching.nativeCompletedPV = [112, 113, 98]
        XCTAssertEqual(teaching.visibleTeachingCandidate, 112)
        XCTAssertEqual(teaching.visibleTeachingPV, [112, 113, 98])
        teaching.verifiedTeachingCandidate = 225
        XCTAssertTrue(teaching.visibleTeachingPV.isEmpty)
        XCTAssertNil(teaching.visibleTeachingCandidate)
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

    func testNativePVValidationUsesFullGomokuTurnAndBoardRules() {
        let empty = GomokuState()
        XCTAssertEqual(
            EclipseThinkingHUDPVReplay.validate(
                [112, 113, 98], from: empty, depth: 3, expectedFirstMove: 112
            ), [112, 113, 98]
        )
        XCTAssertNil(EclipseThinkingHUDPVReplay.validate(
            [112, 112], from: empty, depth: 3, expectedFirstMove: 112
        )) // duplicate cell
        XCTAssertNil(EclipseThinkingHUDPVReplay.validate(
            [112, 113], from: empty, depth: 1, expectedFirstMove: 112
        )) // depth not fully completed
        XCTAssertNil(EclipseThinkingHUDPVReplay.validate(
            [112, 113], from: empty, depth: 3, expectedFirstMove: 98
        )) // wrong run/best-move identity
        XCTAssertNil(EclipseThinkingHUDPVReplay.validate(
            [225], from: empty, depth: 2, expectedFirstMove: 225
        )) // out of bounds
        var occupied = GomokuState()
        XCTAssertTrue(occupied.apply(index: 112, actor: occupied.currentPlayer))
        XCTAssertNil(EclipseThinkingHUDPVReplay.validate(
            [112], from: occupied, depth: 1, expectedFirstMove: 112
        )) // already played on the real match
        let tooLong = [Int](0..<17)
        XCTAssertNil(EclipseThinkingHUDPVReplay.validate(
            tooLong, from: empty, depth: 20, expectedFirstMove: 0
        ))
    }

    func testCompletedPVRemainsHiddenOutsideAuthorizedLiveTeaching() {
        var teaching = EclipseThinkingHUDSnapshot(
            searchID: UUID(), positionRevision: 2, context: .teaching,
            isSearching: true, backend: "C++20 V2",
            executedModel: "ECLIPSE 2.0 Astra", checkpointSHA256: nil,
            computePolicySHA256: nil, elapsedMilliseconds: 1000,
            visitedNodes: 4500, completedDepth: 3, stopReason: nil
        )
        teaching.verifiedTeachingCandidate = 112
        teaching.nativeCompletedPV = [112, 113, 98]
        XCTAssertEqual(teaching.visibleTeachingPV.count, 3)
        teaching.nativeCompletedPV = [113, 112]
        XCTAssertTrue(teaching.visibleTeachingPV.isEmpty) // wrong root
        func fixture(
            _ context: EclipseThinkingHUDSnapshot.Context,
            searching: Bool
        ) -> EclipseThinkingHUDSnapshot {
            var result = EclipseThinkingHUDSnapshot(
                searchID: UUID(), positionRevision: 2, context: context,
                isSearching: searching, backend: "C++20 V2",
                executedModel: "ECLIPSE 2.0 Astra", checkpointSHA256: nil,
                computePolicySHA256: nil, elapsedMilliseconds: 1000,
                visitedNodes: 4500, completedDepth: 3, stopReason: nil
            )
            result.verifiedTeachingCandidate = 112
            result.nativeCompletedPV = [112, 113, 98]
            return result
        }
        XCTAssertTrue(fixture(.teaching, searching: false).visibleTeachingPV.isEmpty)
        XCTAssertTrue(fixture(.formal, searching: true).visibleTeachingPV.isEmpty)
        XCTAssertTrue(fixture(.postgame, searching: true).visibleTeachingPV.isEmpty)
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
        XCTAssertEqual(controller.teachingPVPreviewCount, 0)
        XCTAssertTrue(snapshot.visibleTeachingPV.isEmpty)
    }
}
