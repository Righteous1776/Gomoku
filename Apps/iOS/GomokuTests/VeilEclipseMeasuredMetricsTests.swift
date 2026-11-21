import Foundation
import XCTest
@testable import Gomoku

final class VeilEclipseMeasuredMetricsTests: XCTestCase {
    private func event(depth: Int, nodes: Int) -> VeilGomokuUnifiedSearch.Trace {
        .init(
            phase: .deepening,
            completedDepth: depth, nodes: nodes,
            rootCandidates: 8, selectedIndex: nil, score: nil,
            variation: [], rule: "native-search-test-fixture"
        )
    }

    func testOnlyActualBoundedSessionTracePublishesDepthAndNodeCount() {
        let store = VeilEclipseMeasuredMetricsStore()
        let valid = store.begin(sessionID: "match-A", turn: 5)
        XCTAssertNil(store.snapshot(sessionID: "match-A", turn: 5, isThinking: true))
        XCTAssertTrue(store.record(event(depth: 1, nodes: 120), token: valid))
        XCTAssertTrue(store.record(event(depth: 3, nodes: 860), token: valid))
        let metrics = store.snapshot(sessionID: "match-A", turn: 5, isThinking: true)
        XCTAssertEqual(metrics?.completedDepth, 3)
        XCTAssertEqual(metrics?.visitedNodes, 860)
        XCTAssertNil(store.snapshot(sessionID: "match-B", turn: 5, isThinking: true))
        XCTAssertNil(store.snapshot(sessionID: "match-A", turn: 6, isThinking: true))
        XCTAssertNil(store.snapshot(sessionID: "match-A", turn: 5, isThinking: false))
        XCTAssertFalse(store.record(event(depth: 2, nodes: 859), token: valid))
        XCTAssertFalse(store.record(event(depth: 64, nodes: 500_000_001), token: valid))
        XCTAssertEqual(
            store.snapshot(sessionID: "match-A", turn: 5, isThinking: true)?.visitedNodes, 860
        )
    }

    func testResetRevokesOldTraceToken() {
        let store = VeilEclipseMeasuredMetricsStore()
        let old = store.begin(sessionID: "old", turn: 2)
        XCTAssertTrue(store.record(event(depth: 2, nodes: 500), token: old))
        store.clear()
        XCTAssertNil(store.snapshot(sessionID: "old", turn: 2, isThinking: true))
        let fresh = store.begin(sessionID: "new", turn: 0)
        XCTAssertFalse(store.record(event(depth: 6, nodes: 5_000), token: old))
        XCTAssertTrue(store.record(event(depth: 1, nodes: 100), token: fresh))
        XCTAssertEqual(
            store.snapshot(sessionID: "new", turn: 0, isThinking: true)?.completedDepth, 1
        )
    }
}
