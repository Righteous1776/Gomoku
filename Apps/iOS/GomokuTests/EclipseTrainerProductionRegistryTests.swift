import Foundation
import XCTest
@testable import Gomoku

final class EclipseTrainerProductionRegistryTests: XCTestCase {
    private let sampleDigest = String(repeating: "d", count: 64)

    private func manifest(
        checkpoint: String,
        policyHash: String
    ) throws -> Data {
        let record: [String: Any] = [
            "schema": "eclipse.production-model-binding.v1",
            "model_id": "eclipse-1.0-astra",
            "training_revision": "R29",
            "checkpoint_sha256": checkpoint,
            "compute_policy_sha256": policyHash,
            "compute_policy": [
                "mode": "adaptive",
                "max_wall_time_ms": NSNull(),
                "max_nodes": NSNull(),
                "max_depth": 15,
                "root_width": 60,
                "reply_width": 40,
                "continuation_width": 30,
                "forced_line_depth": 10,
                "candidate_radius": 5
            ] as [String: Any]
        ]
        return try JSONSerialization.data(
            withJSONObject: record, options: [.sortedKeys]
        )
    }

    func testOnlyActuallyLoadedCppCheckpointCanActivateProduction() throws {
        let policy = EclipseTrainerComputePolicy(
            mode: .adaptive, maxWallTimeMilliseconds: nil, maxNodes: nil,
            maxDepth: 15, rootWidth: 60, replyWidth: 40,
            continuationWidth: 30, forcedLineDepth: 10, candidateRadius: 5
        )
        let blob = try manifest(
            checkpoint: sampleDigest,
            policyHash: try XCTUnwrap(policy.sha256)
        )
        let resolved = EclipseTrainerProductionRegistry.resolve(
            manifestData: blob, cppLoadedCheckpointSHA256: sampleDigest
        )
        XCTAssertEqual(resolved?.checkpointSHA256, sampleDigest)
        XCTAssertEqual(resolved?.model, .astra10)
        XCTAssertEqual(resolved?.trainingRevision, "R29")
        XCTAssertEqual(resolved?.computePolicy.maxWallTimeMilliseconds, nil)
        XCTAssertNil(EclipseTrainerProductionRegistry.resolve(
            manifestData: blob, cppLoadedCheckpointSHA256: nil
        ))
        XCTAssertNil(EclipseTrainerProductionRegistry.resolve(
            manifestData: blob,
            cppLoadedCheckpointSHA256: String(repeating: "a", count: 64)
        ))
    }

    func testIncorrectPolicyDigestAndPrivateFieldsAreRefused() throws {
        let blob = try manifest(
            checkpoint: sampleDigest,
            policyHash: String(repeating: "0", count: 64)
        )
        XCTAssertNil(EclipseTrainerProductionRegistry.resolve(
            manifestData: blob, cppLoadedCheckpointSHA256: sampleDigest
        ))

        var record = try XCTUnwrap(
            JSONSerialization.jsonObject(with: blob) as? [String: Any]
        )
        record["private_match_history"] = [0, 1, 2, 3]
        let forged = try JSONSerialization.data(withJSONObject: record)
        XCTAssertNil(EclipseTrainerProductionRegistry.resolve(
            manifestData: forged, cppLoadedCheckpointSHA256: sampleDigest
        ))
    }
}