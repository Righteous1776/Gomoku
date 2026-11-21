import Foundation
import XCTest
@testable import Gomoku

/// Research-only actual iOS Swift -> C ABI V2 -> C++ search tests.
/// No personal VeilLink histories, R29 checkpoints or production promotion.
final class EclipseCppTrainerPolicyV2Tests: XCTestCase {
    private func policy(
        milliseconds: Int? = nil,
        maxDepth: Int = 15,
        width: Int = 60,
        forced: Int = 10
    ) -> EclipseTrainerComputePolicy {
        EclipseTrainerComputePolicy(
            mode: milliseconds == nil ? .adaptive : .budgeted,
            maxWallTimeMilliseconds: milliseconds,
            maxNodes: nil, maxDepth: maxDepth,
            rootWidth: width, replyWidth: 40, continuationWidth: 30,
            forcedLineDepth: forced, candidateRadius: 5
        )
    }

    func testNewCABIIsVersionedAndDeepPolicyHasNoHiddenTimeLimit() {
        XCTAssertEqual(eg_compute_policy_abi_version(), 2)
        let history = [0, 15, 1, 16, 2, 17, 3, 18]
        for requested in [nil, 123_456] as [Int?] {
            let selected = policy(milliseconds: requested)
            let run = EclipseCppResearchFixture.runTrainerComputeV2(
                history: history, policy: selected
            )
            XCTAssertEqual(run?.move, 4)
            XCTAssertEqual(run?.appliedPolicyDigest, selected.sha256)
            XCTAssertNotNil(run?.elapsedMilliseconds)
        }
    }

    func testTrainerDepthAndWidthChangeRealCppSearch() {
        let opening = [112, 97]
        let shallow = policy(maxDepth: 1, width: 2, forced: 0)
        let deep = policy(maxDepth: 2, width: 6, forced: 0)
        let a = EclipseCppResearchFixture.runTrainerComputeV2(
            history: opening, policy: shallow)
        let b = EclipseCppResearchFixture.runTrainerComputeV2(
            history: opening, policy: deep)
        XCTAssertEqual(a?.completedDepth, 1)
        XCTAssertEqual(b?.completedDepth, 2)
        XCTAssertNotNil(a?.move)
        XCTAssertNotNil(b?.move)
        XCTAssertEqual(a?.appliedPolicyDigest, shallow.sha256)
        XCTAssertEqual(b?.appliedPolicyDigest, deep.sha256)
    }

    func testRealCppCannotLetLearningBypassForcedWin() {
        let history = [0, 15, 1, 16, 2, 17, 3, 18]
        let chosen = policy()
        var allowed = Set(0..<225)
        let safe = EclipseCppResearchFixture.runTrainerComputeV2(
            history: history, policy: chosen, allowedRoots: allowed,
            rootBonuses: [9: 2_000, 4: -2_000])
        XCTAssertEqual(safe?.move, 4)
        allowed.remove(4)
        XCTAssertNil(EclipseCppResearchFixture.runTrainerComputeV2(
            history: history, policy: chosen, allowedRoots: allowed,
            rootBonuses: [9: 2_000]),
            "Excluding mandatory winning square must fail closed")
    }
}
