import Foundation
import XCTest
@testable import Gomoku

final class EclipseV9DualBindingTests: XCTestCase {
    private let astraSHA =
        "d50190d02bf6ebd6f447d84a2920184964ac9cff1dcc0712b0076cec326a177d"
    private let solSHA =
        "074140fa99d52143ce3b887a553f1f11586973096baaada6476f97004e4b4fdd"

    private func record(
        model: EclipseModelID, sha: String
    ) throws -> [String: Any] {
        let astra = model == .astra20
        let policy = EclipseTrainerComputePolicy(
            mode: .budgeted,
            maxWallTimeMilliseconds: astra ? 30_000 : 8_000,
            maxNodes: astra ? 1_200_000 : 400_000,
            maxDepth: astra ? 12 : 9,
            rootWidth: astra ? 24 : 16,
            replyWidth: astra ? 16 : 10,
            continuationWidth: astra ? 8 : 6,
            forcedLineDepth: astra ? 8 : 6,
            candidateRadius: astra ? 3 : 2
        )
        return [
            "schema": "eclipse.production-model-binding.v1",
            "model_id": model.rawValue,
            "training_revision": "V9",
            "checkpoint_sha256": sha,
            "compute_policy_sha256": try XCTUnwrap(policy.sha256),
            "compute_policy": try XCTUnwrap(
                JSONSerialization.jsonObject(
                    with: try XCTUnwrap(policy.canonicalData)
                ) as? [String: Any]
            )
        ]
    }

    private func catalog(_ records: [[String: Any]]) throws -> Data {
        try JSONSerialization.data(
            withJSONObject: [
                "schema": "eclipse.production-model-catalog.v2",
                "models": records
            ] as [String: Any],
            options: [.sortedKeys]
        )
    }

    func testBothV9ModelsResolveToDistinctCheckpoints() throws {
        let blob = try catalog([
            record(model: .astra20, sha: astraSHA),
            record(model: .sol20, sha: solSHA)
        ])
        let accepted = EclipseTrainerProductionRegistry.resolveCatalog(
            manifestData: blob
        ) { _, expected in expected }
        XCTAssertEqual(accepted.count, 2)
        XCTAssertEqual(accepted[.astra20]?.checkpointSHA256, astraSHA)
        XCTAssertEqual(accepted[.sol20]?.checkpointSHA256, solSHA)
        XCTAssertEqual(accepted[.astra20]?.trainingRevision, "V9")
        XCTAssertEqual(accepted[.sol20]?.trainingRevision, "V9")
        XCTAssertEqual(
            Array(EclipseModelID.featuredIncludingVerified(
                Array(accepted.keys)
            ).prefix(2)),
            [.astra20, .sol20]
        )
    }

    func testCorruptedOrDuplicateCatalogFailsClosed() throws {
        let astra = try record(model: .astra20, sha: astraSHA)
        let sol = try record(model: .sol20, sha: solSHA)
        let duplicate = try catalog([astra, astra])
        XCTAssertTrue(EclipseTrainerProductionRegistry.resolveCatalog(
            manifestData: duplicate
        ) { _, sha in sha }.isEmpty)
        let corrupted = try catalog([astra, sol])
        XCTAssertTrue(EclipseTrainerProductionRegistry.resolveCatalog(
            manifestData: corrupted
        ) { model, sha in model == .sol20 ? astraSHA : sha }.isEmpty)
        XCTAssertTrue(EclipseTrainerProductionRegistry.resolveCatalog(
            manifestData: corrupted
        ) { _, _ in nil }.isEmpty)
    }

    func testAppBundleContainsBothValidV9ModelBindings() {
        // The metadata must be included in the ACTUAL application binary's
        // bundle; passing the isolated decoder test is not sufficient.
        let appBundle = Bundle(for: EclipseCppProductionAdapter.self)
        XCTAssertNotNil(appBundle.url(
            forResource: "ECLIPSE_ACTIVE_MODELS", withExtension: "json"
        ))
        let models = EclipseTrainerProductionRegistry.loadAllFromBundle(
            appBundle
        )
        XCTAssertEqual(models.count, 3)
        XCTAssertEqual(models[.astra30]?.checkpointSHA256,
                       "d4cea7f62e9e8ffc119d60861ce05df43aafdbdc280b51707dc1b7e40e5fc234")
        XCTAssertEqual(models[.astra20]?.checkpointSHA256, astraSHA)
        XCTAssertEqual(models[.sol20]?.checkpointSHA256, solSHA)
    }

    func testVerifiedLocalRepertoireReachesCppRootPolicy() throws {
        var state = GomokuState()
        XCTAssertTrue(state.apply(index: 112, actor: .host))
        XCTAssertTrue(state.apply(index: 97, actor: .guest))
        let local = AdaptiveBoardLearningSnapshot(
            preferences: [
                AdaptiveBoardPosition.gomoku(state): ["113": 400]
            ],
            rootAdjustments: ["113": 300],
            predictedHumanReplies: [:],
            trainingLevel: 0
        )
        let root = EclipseCppRootLearningPolicy.build(
            state: state, player: state.currentPlayer,
            learning: local, formation: .disabled
        )
        XCTAssertTrue(root.isValid)
        XCTAssertEqual(root.allowed.count, 225)
        XCTAssertEqual(root.bonuses[113], 700)
        XCTAssertEqual(root.bonuses[112], 0)
        XCTAssertEqual(root.bonuses[97], 0)
        XCTAssertTrue(root.allowed.allSatisfy { $0 == 1 })
    }

    func testSwiftToRealCppV2MoveForBothApprovedModels() throws {
        let manifest = EclipseTrainerProductionRegistry.loadAllFromBundle(
            Bundle(for: EclipseCppProductionAdapter.self)
        )
        let uniqueBlockHistory = [10, 4, 79, 19, 95, 34, 111, 49]
        for model in [EclipseModelID.astra20, .sol20] {
            let trainer = try XCTUnwrap(manifest[model])
            let running = try XCTUnwrap(EclipseCppProductionAdapter.make(
                history: uniqueBlockHistory, trainer: trainer
            ))
            let decision = try XCTUnwrap(running.decide(
                policy: trainer.computePolicy
            ))
            XCTAssertEqual(decision.index, 64)
            XCTAssertTrue(
                (decision.engineLabel ?? "").contains(model.family)
            )
            // Local repeated-tactic preference must never overpower a
            // mandatory immediate defense, even at the maximum bonus range.
            let favoredWrongMove = AdaptiveBoardLearningSnapshot(
                preferences: [:],
                rootAdjustments: ["63": 2_000, "64": -2_000],
                predictedHumanReplies: [:],
                trainingLevel: 0
            )
            var forcedBoard = GomokuState()
            for move in uniqueBlockHistory {
                XCTAssertTrue(forcedBoard.apply(
                    index: move, actor: forcedBoard.currentPlayer
                ))
            }
            let root = EclipseCppRootLearningPolicy.build(
                state: forcedBoard, player: forcedBoard.currentPlayer,
                learning: favoredWrongMove, formation: .disabled
            )
            XCTAssertEqual(root.bonuses[63], 2_000)
            XCTAssertEqual(root.bonuses[64], -2_000)
            XCTAssertEqual(try XCTUnwrap(
                running.decide(
                    policy: trainer.computePolicy, rootPolicy: root
                )
            ).index, 64)
            // A mismatched compute policy cannot bypass Training Agent
            // authorization, even if it could have produced the same move.
            let bad = EclipseTrainerComputePolicy(
                mode: .budgeted,
                maxWallTimeMilliseconds: 100,
                maxNodes: 1_000,
                maxDepth: 1,
                rootWidth: 1,
                replyWidth: 1,
                continuationWidth: 1,
                forcedLineDepth: 0,
                candidateRadius: 2
            )
            XCTAssertNil(running.decide(policy: bad))
        }
    }

    func testRealCompiledV9RuntimeBindsTwoDifferentForestHashes() {
        let actualAstra = EclipseCppProductionAdapter.loadedCheckpointSHA256(
            for: .astra20, expectedSHA256: astraSHA
        )
        let actualSol = EclipseCppProductionAdapter.loadedCheckpointSHA256(
            for: .sol20, expectedSHA256: solSHA
        )
        XCTAssertEqual(actualAstra, astraSHA)
        XCTAssertEqual(actualSol, solSHA)
        XCTAssertNotEqual(actualAstra, actualSol)
        XCTAssertNil(EclipseCppProductionAdapter.loadedCheckpointSHA256(
            for: .astra20, expectedSHA256: solSHA
        ))
        XCTAssertNil(EclipseCppProductionAdapter.loadedCheckpointSHA256(
            for: .sol20, expectedSHA256: astraSHA
        ))
        XCTAssertNil(EclipseCppProductionAdapter.loadedCheckpointSHA256(
            for: .astra10, expectedSHA256: astraSHA
        ))
    }
}
