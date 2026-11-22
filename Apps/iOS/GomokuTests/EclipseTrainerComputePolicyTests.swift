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

    func testFourManualTiersChangeActualNativeSearchBudgetAndKeepSafety() throws {
        let base = EclipseTrainerComputePolicy(
            mode: .budgeted, maxWallTimeMilliseconds: 30_000,
            maxNodes: 1_200_000, maxDepth: 12,
            rootWidth: 24, replyWidth: 16, continuationWidth: 8,
            forcedLineDepth: 8, candidateRadius: 3
        )
        let configurations = EclipseComputeTier.allCases.map { base.withManualTier($0) }
        XCTAssertEqual(configurations.map(\.maxWallTimeMilliseconds), [7500, 15000, 22500, 30000])
        XCTAssertEqual(configurations.map(\.maxNodes), [300_000, 600_000, 900_000, 1_200_000])
        XCTAssertEqual(configurations.map(\.maxDepth), [3, 6, 9, 12])
        XCTAssertEqual(configurations.map(\.rootWidth), [6, 12, 18, 24])
        XCTAssertEqual(configurations.map(\.replyWidth), [4, 8, 12, 16])
        XCTAssertTrue(configurations.allSatisfy { $0.isValid })
        XCTAssertTrue(configurations.allSatisfy { $0.forcedLineDepth == 8 && $0.candidateRadius == 3 })
        XCTAssertEqual(Set(configurations.compactMap(\.sha256)).count, 4)
        XCTAssertEqual(base.sha256, configurations.last?.sha256)
        XCTAssertNil(adaptive().withManualTier(.light).maxWallTimeMilliseconds)
        XCTAssertNil(adaptive().withManualTier(.standard).maxNodes)
    }

    func testTenThinkingStrengthPositionsBoundedByManualTier() throws {
        let base = EclipseTrainerComputePolicy(
            mode: .budgeted, maxWallTimeMilliseconds: 30_000,
            maxNodes: 1_200_000, maxDepth: 12,
            rootWidth: 24, replyWidth: 16, continuationWidth: 8,
            forcedLineDepth: 8, candidateRadius: 3
        ).withManualTier(.extreme)
        let low = base.withThinkingIntensity(1)
        let high = base.withThinkingIntensity(10)
        XCTAssertEqual(high, base)
        XCTAssertEqual(low.maxWallTimeMilliseconds, 3000)
        XCTAssertEqual(low.maxNodes, 120_000)
        XCTAssertTrue(low.maxDepth < high.maxDepth)
        XCTAssertEqual(low.forcedLineDepth, 8)
        XCTAssertEqual(low.candidateRadius, 3)
        XCTAssertNotEqual(low.runtimeSignature(noWallTimeCutoff: true),
                          low.runtimeSignature(noWallTimeCutoff: false))
        XCTAssertTrue((1...10).allSatisfy {
            base.withThinkingIntensity($0).isValid
        })
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
        XCTAssertEqual(policy.sha256, "559e3830c4441cfa143c302ac4c749fdbe6371c526f74eb627b9686ebde099b1")
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
            model: .astra20, trainingRevision: "R29",
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
        // The verified trainer token belongs to 2.0 Astra only; legacy
        // 1.0 Astra must never masquerade as a loaded native model.
        controller.selectModel(.astra20)
        XCTAssertTrue(controller.trainerControlsCompute)
        XCTAssertEqual(policy.budget().timeLimitMilliseconds, 0)
        controller.selectModel(.sol10)
        XCTAssertFalse(controller.trainerControlsCompute)
        // No test shortcut may silently change the unverified Sol engine.
        XCTAssertEqual(controller.difficulty, .advanced)
    }
}
