import Foundation
import XCTest
@testable import Gomoku

@MainActor
final class EclipseTrainerComputePolicyTests: XCTestCase {
    private func adaptive() -> EclipseTrainerComputePolicy {
        EclipseTrainerComputePolicy(
            mode: .adaptive,
            maxWallTimeMilliseconds: nil,
            maxNodes: nil,
            maxDepth: 15,
            rootWidth: 70,
            replyWidth: 42,
            continuationWidth: 30,
            forcedLineDepth: 12,
            candidateRadius: 3
        )
    }

    func testTrainerAdaptiveHasNoArtificialTimeOrNodeCeiling() throws {
        let policy = adaptive()
        XCTAssertTrue(policy.isValid)
        XCTAssertNil(policy.maxWallTimeMilliseconds)
        XCTAssertEqual(policy.budget().timeLimitMilliseconds, 0)
        XCTAssertEqual(policy.unifiedLimits().maxMilliseconds, 0)
        XCTAssertEqual(policy.unifiedLimits().maxNodes, 0)
        XCTAssertEqual(policy.unifiedLimits().maxDepth, 15)
        XCTAssertEqual(policy.unifiedLimits().width, 70)
        XCTAssertEqual(policy.unifiedLimits().forcedLineDepth, 12)
        XCTAssertEqual(policy.budget().reinforced(by: 8).timeLimitMilliseconds, 0)
        let canonical = try XCTUnwrap(policy.canonicalData)
        let encoded = try XCTUnwrap(String(data: canonical, encoding: .utf8))
        XCTAssertTrue(encoded.contains("\"max_wall_time_ms\":null"))
        XCTAssertTrue(encoded.contains("\"max_nodes\":null"))
        XCTAssertEqual(policy.sha256?.count, 64)
    }

    func testTrainerCanSetLargeExplicitBudgetWithoutLegacy5700msCeiling() {
        let chosen = EclipseTrainerComputePolicy(
            mode: .budgeted,
            maxWallTimeMilliseconds: 123_456,
            maxNodes: 35_000_000,
            maxDepth: 14,
            rootWidth: 84,
            replyWidth: 53,
            continuationWidth: 32,
            forcedLineDepth: 11,
            candidateRadius: 3
        )
        XCTAssertTrue(chosen.isValid)
        XCTAssertEqual(chosen.budget().timeLimitMilliseconds, 123_456)
        XCTAssertEqual(chosen.unifiedLimits().maxMilliseconds, 123_456)
        XCTAssertEqual(chosen.unifiedLimits().maxNodes, 35_000_000)
        XCTAssertEqual(chosen.unifiedLimits().maxDepth, 14)
    }

    func testUnverifiedCheckpointOrPolicyCannotTakeControl() {
        let policy = adaptive()
        let hash = String(repeating: "a", count: 64)
        let digest = policy.sha256!
        let candidate = EclipseVerifiedTrainerExecution(
            model: .astra10,
            trainingRevision: "R29",
            checkpointSHA256: hash,
            loadedCheckpointSHA256: hash,
            computePolicy: policy,
            approvedComputePolicySHA256: digest,
            loadedComputePolicySHA256: digest
        )
        XCTAssertNotNil(candidate)
        XCTAssertNil(EclipseVerifiedTrainerExecution(
            model: .astra10, trainingRevision: "R29",
            checkpointSHA256: hash,
            loadedCheckpointSHA256: String(repeating: "b", count: 64),
            computePolicy: policy,
            approvedComputePolicySHA256: digest,
            loadedComputePolicySHA256: digest))
        XCTAssertNil(EclipseVerifiedTrainerExecution(
            model: .astra10, trainingRevision: "R29",
            checkpointSHA256: hash,
            loadedCheckpointSHA256: hash,
            computePolicy: policy,
            approvedComputePolicySHA256: String(repeating: "0", count: 64),
            loadedComputePolicySHA256: digest))
    }

    func testControllerUsesActualVerifiedPolicyAndPreservesOldSwiftFallback() throws {
        let policy = adaptive()
        let hash = String(repeating: "a", count: 64)
        let digest = try XCTUnwrap(policy.sha256)
        let token = try XCTUnwrap(EclipseVerifiedTrainerExecution(
            model: .astra10, trainingRevision: "R29",
            checkpointSHA256: hash, loadedCheckpointSHA256: hash,
            computePolicy: policy,
            approvedComputePolicySHA256: digest, loadedComputePolicySHA256: digest
        ))
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("Eclipse-R16-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let controller = NativeGomokuAppController(
            archiveDirectory: dir.appendingPathComponent("history"),
            trainingDirectory: dir.appendingPathComponent("training"),
            verifiedTrainerExecution: token)
        XCTAssertFalse(controller.trainerControlsCompute)
        controller.selectModel(.astra10)
        XCTAssertTrue(controller.trainerControlsCompute)
        XCTAssertEqual(policy.budget().timeLimitMilliseconds, 0)
        controller.selectModel(.sol10)
        XCTAssertFalse(controller.trainerControlsCompute)
        // No test shortcut may silently change the unverified Sol engine.
        XCTAssertEqual(controller.difficulty, .advanced)
    }
}
