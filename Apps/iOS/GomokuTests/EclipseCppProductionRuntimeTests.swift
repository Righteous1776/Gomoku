import Foundation
import XCTest
@testable import Gomoku

/// These tests run the production-compiled adapter, NOT a DEBUG research wrapper.
final class EclipseCppProductionRuntimeTests: XCTestCase {
    private func policy() -> EclipseTrainerComputePolicy {
        EclipseTrainerComputePolicy(
            mode: .adaptive, maxWallTimeMilliseconds: nil, maxNodes: nil,
            maxDepth: 15, rootWidth: 60, replyWidth: 40,
            continuationWidth: 30, forcedLineDepth: 10,
            candidateRadius: 5
        )
    }

    func testProductionCPPIsCompiledWithActualPolicyV2ABI() {
        XCTAssertEqual(eg_compute_policy_abi_version(), 2)
        let actual = EclipseCppProductionAdapter.loadedCheckpointSHA256()
        if let actual {
            XCTAssertEqual(actual.count, 64)
            XCTAssertTrue(actual.utf8.allSatisfy {
                (48...57).contains(Int($0)) || (97...102).contains(Int($0))
            })
        }
    }

    func testTheFrozenR10PrototypeCannotImpersonateATrainedModel() throws {
        let p = policy()
        let hash = String(repeating: "a", count: 64)
        let approved = try XCTUnwrap(EclipseVerifiedTrainerExecution(
            model: .astra10, trainingRevision: "R29",
            checkpointSHA256: hash,
            loadedCheckpointSHA256: hash,
            computePolicy: p,
            approvedComputePolicySHA256: try XCTUnwrap(p.sha256),
            loadedComputePolicySHA256: try XCTUnwrap(p.sha256)
        ))
        guard EclipseCppProductionAdapter.loadedCheckpointSHA256() != hash else {
            // If this test fixture hash ever becomes the real loaded model,
            // skip only the negative assertion, not all other production tests.
            return
        }
        XCTAssertNil(EclipseCppProductionAdapter.make(
            history: [0, 15, 1, 16, 2, 17, 3, 18],
            trainer: approved
        ), "A manifest-only R29 token must NOT activate the untrained C++ prototype")
    }

    @MainActor
    func testOfficialControllerExposesActualBackendNotRequestedLabel() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("EclipseCppProduction-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let controller = NativeGomokuAppController(
            archiveDirectory: dir.appendingPathComponent("history"),
            trainingDirectory: dir.appendingPathComponent("training"))
        XCTAssertNil(controller.lastExecutionBackend)
        XCTAssertNil(controller.lastExecutedTrainerRevision)
        controller.selectModel(.astra10)
        XCTAssertNil(controller.lastExecutionBackend)
        XCTAssertFalse(controller.trainerControlsCompute)
    }
}