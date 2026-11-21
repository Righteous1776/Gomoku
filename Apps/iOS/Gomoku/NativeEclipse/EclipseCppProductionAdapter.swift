import Foundation

/// Production-capable C++ V2 execution adapter.
///
/// This file deliberately has NO #if DEBUG: the architecture is compiled into
/// both Debug and Release apps. It becomes the chosen inference path only when
/// the actual C++ scorer reports the same loaded checkpoint digest as the
/// specialized Training Agent's independently verified handoff.
///
/// The public R17 prototype still contains R10 ordering but no R29/214-tree
/// loaded checkpoint. It must not silently impersonate the latest trained AI.
/// Each reading is from one actual C++ search, never from a generated timer
/// or guessed best move. Only nodes and completed depth reach the formal HUD.
struct EclipseCppLiveSearchReading: Equatable {
    let searchSerial: UInt64
    let running: Bool
    let nodes: Int
    let completedDepth: Int?
    let bestMoveForAuthorizedReview: Int?
}

final class EclipseCppProductionAdapter: @unchecked Sendable {
    private let engine: OpaquePointer
    private let checkpointSHA256: String
    private let model: EclipseModelID
    private let approvedComputePolicySHA256: String

    /// The compiled Astra and Sol forests have DISTINCT immutable identities.
    private static func nativeRanker(_ model: EclipseModelID) -> Int32? {
        switch model {
        case .astra20: return Int32(EG_RESEARCH_RANKER_V9_ASTRA)
        case .sol20: return Int32(EG_RESEARCH_RANKER_V9_SOL)
        default: return nil
        }
    }

    private init?(
        history: [Int], model: EclipseModelID, checkpointSHA256: String,
        approvedComputePolicySHA256: String
    ) {
        guard let selected = Self.nativeRanker(model),
              let created = eg_create() else { return nil }
        let bound = checkpointSHA256.withCString {
            eg_select_compiled_v9_model_v4(created, selected, $0)
        }
        guard bound == 1,
              Self.activeCheckpointSHA256(of: created) == checkpointSHA256
        else {
            eg_destroy(created)
            return nil
        }
        for index in history {
            guard (0..<225).contains(index),
                  eg_play(created, Int32(index)) == 1 else {
                eg_destroy(created)
                return nil
            }
        }
        guard eg_status(created) == 0 else {
            eg_destroy(created)
            return nil
        }
        engine = created
        self.checkpointSHA256 = checkpointSHA256
        self.model = model
        self.approvedComputePolicySHA256 = approvedComputePolicySHA256
    }

    deinit { eg_destroy(engine) }

    /// This digest must come from the *actually loaded C++ scorer*, not the
    /// manifest or the application's model picker. Zero means not loaded.
    static func loadedCheckpointSHA256() -> String? {
        var bytes = [CChar](repeating: 0, count: 65)
        let read = bytes.withUnsafeMutableBufferPointer { buffer in
            eg_active_trained_checkpoint_sha256_v2(
                buffer.baseAddress, Int32(buffer.count)
            )
        }
        guard read == 64, bytes[64] == 0 else { return nil }
        let raw = bytes.prefix(64).map { UInt8(bitPattern: $0) }
        guard let text = String(bytes: raw, encoding: .utf8),
              text.count == 64,
              text.utf8.allSatisfy({
                  ($0 >= 48 && $0 <= 57) || ($0 >= 97 && $0 <= 102)
              }) else { return nil }
        return text
    }

    /// Read identity of the ACTIVE forest of this engine instance, never a
    /// model-picker label or the old global R10 research checkpoint stub.
    private static func activeCheckpointSHA256(
        of engine: OpaquePointer
    ) -> String? {
        var bytes = [CChar](repeating: 0, count: 65)
        let read = bytes.withUnsafeMutableBufferPointer { buffer in
            eg_active_compiled_v9_sha256_v4(
                engine, buffer.baseAddress, Int32(buffer.count)
            )
        }
        guard read == 64, bytes[64] == 0 else { return nil }
        let raw = bytes.prefix(64).map { UInt8(bitPattern: $0) }
        guard let digest = String(bytes: raw, encoding: .utf8),
              digest.count == 64,
              digest.utf8.allSatisfy({
                ($0 >= 48 && $0 <= 57) || ($0 >= 97 && $0 <= 102)
              }) else { return nil }
        return digest
    }

    /// Used for discovery only: create a temporary native engine and prove
    /// it can bind this *specific* model and the expected source SHA.
    static func loadedCheckpointSHA256(
        for model: EclipseModelID, expectedSHA256: String
    ) -> String? {
        guard let selected = nativeRanker(model),
              expectedSHA256.count == 64,
              let handle = eg_create() else { return nil }
        defer { eg_destroy(handle) }
        let ok = expectedSHA256.withCString {
            eg_select_compiled_v9_model_v4(handle, selected, $0)
        }
        guard ok == 1 else { return nil }
        return activeCheckpointSHA256(of: handle)
    }

    /// Runtime dispatch authority: real C++ loaded model and trainer handoff
    /// must agree byte-for-byte. Merely having a C++ ABI does not suffice.
    static func make(
        history: [Int],
        trainer: EclipseVerifiedTrainerExecution
    ) -> EclipseCppProductionAdapter? {
        guard eg_compute_policy_abi_version() == 2,
              let policyDigest = trainer.computePolicy.sha256,
              loadedCheckpointSHA256(
                for: trainer.model, expectedSHA256: trainer.checkpointSHA256
              ) == trainer.checkpointSHA256
        else { return nil }
        return EclipseCppProductionAdapter(
            history: history, model: trainer.model,
            checkpointSHA256: trainer.checkpointSHA256,
            approvedComputePolicySHA256: policyDigest
        )
    }

    /// Safe to invoke concurrently with a running analyze call on this
    /// instance; the C ABI only permits atomic cancellation during search.
    /// Do NOT play, reset, or destroy the native engine while search runs.
    func cancel() {
        eg_cancel_search_v2(engine)
    }

    /// The C++ ABI uses atomic, sequence-checked reads. The SwiftUI layer
    /// polls at no more than its existing 2 Hz budget. This never calls a
    /// search or mutates the board; no live candidate reaches formal matches.
    func liveSearchSnapshot() -> EclipseCppLiveSearchReading? {
        var reading = EGSearchLiveSnapshotV1()
        reading.size_bytes = UInt32(MemoryLayout<EGSearchLiveSnapshotV1>.size)
        guard eg_read_live_search_v1(engine, &reading) == 1,
              reading.size_bytes == UInt32(MemoryLayout<EGSearchLiveSnapshotV1>.size),
              reading.search_serial > 0,
              reading.state == UInt32(EG_LIVE_SEARCH_RUNNING)
                || reading.state == UInt32(EG_LIVE_SEARCH_COMPLETE)
        else { return nil }
        return EclipseCppLiveSearchReading(
            searchSerial: reading.search_serial,
            running: reading.state == UInt32(EG_LIVE_SEARCH_RUNNING),
            nodes: Int(clamping: reading.visited_nodes),
            completedDepth: reading.completed_depth > 0
                ? Int(reading.completed_depth) : nil,
            bestMoveForAuthorizedReview: (0..<225).contains(Int(reading.best_move))
                ? Int(reading.best_move) : nil
        )
    }

    /// Real root shortlist from the same C++ search, in its actual
    /// native rank order. No normalized scores or hypothetical probabilities.
    func liveRankedRootMoves() -> (serial: UInt64, moves: [Int])? {
        var reading = EGRankedRootsSnapshotV1()
        reading.size_bytes = UInt32(MemoryLayout<EGRankedRootsSnapshotV1>.size)
        guard eg_read_ranked_roots_v1(engine, &reading) == 1,
              reading.count > 0,
              reading.count <= UInt32(EG_LIVE_RANKED_ROOTS_MAX),
              reading.search_serial > 0 else { return nil }
        let moves: [Int] = withUnsafeBytes(of: reading.moves) { bytes in
            bytes.bindMemory(to: Int32.self)
                .prefix(Int(reading.count)).map { Int($0) }
        }
        guard moves.count == Int(reading.count),
              Set(moves).count == moves.count,
              moves.allSatisfy({ (0..<225).contains($0) })
        else { return nil }
        return (serial: reading.search_serial, moves: moves)
    }

    /// A short, actual principal variation PREFIX rooted in a finished
    /// iteration and followed exclusively through exact native TT entries.
    /// Position replay/alternating-stone legality is checked by the controller.
    func livePVPrefix() -> (serial: UInt64, depth: Int, moves: [Int])? {
        var reading = EGPVPrefixSnapshotV1()
        reading.size_bytes = UInt32(MemoryLayout<EGPVPrefixSnapshotV1>.size)
        guard eg_read_pv_prefix_v1(engine, &reading) == 1,
              reading.count > 0,
              reading.count <= UInt32(EG_LIVE_PV_PREFIX_MAX),
              reading.completed_depth > 0,
              reading.count <= UInt32(reading.completed_depth),
              reading.search_serial > 0 else { return nil }
        let moves: [Int] = withUnsafeBytes(of: reading.moves) { bytes in
            bytes.bindMemory(to: Int32.self)
                .prefix(Int(reading.count)).map { Int($0) }
        }
        guard moves.count == Int(reading.count),
              Set(moves).count == moves.count,
              moves.allSatisfy({ (0..<225).contains($0) })
        else { return nil }
        return (serial: reading.search_serial,
                depth: Int(reading.completed_depth),
                moves: moves)
    }

    /// Runs the native C++ evaluator once. No app-specific 5.7s/20s limit,
    /// no separate model budget overriding the Training Agent's policy.
    /// The search always executes off the MainActor.
    func decide(
        policy: EclipseTrainerComputePolicy,
        rootPolicy: EclipseCppRootLearningPolicy? = nil
    ) -> GomokuBotMove? {
        guard rootPolicy?.isValid != false,
              policy.isValid,
              policy.sha256 == approvedComputePolicySHA256,
              Self.nativeRanker(model) == eg_research_ranker_v3(engine),
              Self.activeCheckpointSHA256(of: engine) == checkpointSHA256
        else { return nil }
        var config = EGComputePolicyV2()
        config.size_bytes = UInt32(MemoryLayout<EGComputePolicyV2>.size)
        config.mode = policy.mode == .adaptive
            ? UInt32(EG_COMPUTE_MODE_ADAPTIVE)
            : UInt32(EG_COMPUTE_MODE_BUDGETED)
        config.max_wall_time_ms = Int64(policy.maxWallTimeMilliseconds ?? 0)
        config.max_nodes = UInt64(policy.maxNodes ?? 0)
        config.max_depth = Int32(policy.maxDepth)
        config.root_width = Int32(policy.rootWidth)
        config.reply_width = Int32(policy.replyWidth)
        config.continuation_width = Int32(policy.continuationWidth)
        config.forced_line_depth = Int32(policy.forcedLineDepth)
        config.candidate_radius = Int32(policy.candidateRadius)

        // Owner-authorized V3 stopping governs ONLY adaptive timing.
        // Trainer-selected depth, candidate widths and verified model SHA
        // remain intact; legacy budgeted/V2 and maxDepth=1 are untouched.
        let useAdaptiveV3 = policy.mode == .adaptive && policy.maxDepth >= 2
        guard !useAdaptiveV3 || eg_adaptive_stop_abi_version() == 3 else {
            return nil // Never silently fall back to unbounded thinking.
        }
        var stopping = EGAdaptiveStopConfigV3()
        stopping.size_bytes = UInt32(MemoryLayout<EGAdaptiveStopConfigV3>.size)
        stopping.minimum_depth = Int32(min(3, policy.maxDepth))
        stopping.stable_rounds = Int32(min(3, policy.maxDepth))
        stopping.minimum_score_gap = 1800
        // Finite ceilings, not fixed per-move think times: safe early
        // convergence is faster, an ambiguous/tactical board gets longer.
        stopping.clear_budget_ms = 1200
        stopping.uncertain_budget_ms = 6000
        stopping.complex_budget_ms = 45000

        var adaptiveRun = EGAdaptiveRunV3()
        adaptiveRun.size_bytes = UInt32(MemoryLayout<EGAdaptiveRunV3>.size)
        var run = EGComputeRunV2()
        run.size_bytes = UInt32(MemoryLayout<EGComputeRunV2>.size)
        let executed: Int32
        if let rootPolicy {
            // Use the IDENTICAL complete root mask and bonuses for V2/V3.
            executed = rootPolicy.allowed.withUnsafeBufferPointer { allowed in
                rootPolicy.bonuses.withUnsafeBufferPointer { bonuses in
                    if useAdaptiveV3 {
                        return eg_analyze_compute_policy_v3(
                            engine, &config, &stopping,
                            allowed.baseAddress, Int32(allowed.count),
                            bonuses.baseAddress, Int32(bonuses.count),
                            &adaptiveRun
                        )
                    }
                    return eg_analyze_compute_policy_v2(
                        engine, &config,
                        allowed.baseAddress, Int32(allowed.count),
                        bonuses.baseAddress, Int32(bonuses.count),
                        &run
                    )
                }
            }
        } else if useAdaptiveV3 {
            executed = eg_analyze_compute_policy_v3(
                engine, &config, &stopping, nil, 0, nil, 0, &adaptiveRun
            )
        } else {
            executed = eg_analyze_compute_policy_v2(
                engine, &config, nil, 0, nil, 0, &run
            )
        }
        if useAdaptiveV3 && executed == 1 {
            // Fail closed if ABI or applied stopping control differs.
            guard adaptiveRun.size_bytes ==
                    UInt32(MemoryLayout<EGAdaptiveRunV3>.size),
                  adaptiveRun.applied_stopping.size_bytes == stopping.size_bytes,
                  adaptiveRun.applied_stopping.minimum_depth == stopping.minimum_depth,
                  adaptiveRun.applied_stopping.stable_rounds == stopping.stable_rounds,
                  adaptiveRun.applied_stopping.minimum_score_gap == stopping.minimum_score_gap,
                  adaptiveRun.applied_stopping.clear_budget_ms == stopping.clear_budget_ms,
                  adaptiveRun.applied_stopping.uncertain_budget_ms == stopping.uncertain_budget_ms,
                  adaptiveRun.applied_stopping.complex_budget_ms == stopping.complex_budget_ms
            else { return nil }
            run = adaptiveRun.base
        }
        guard executed == 1,
            run.size_bytes == UInt32(MemoryLayout<EGComputeRunV2>.size),
            run.search.size_bytes ==
                UInt32(MemoryLayout<EGSearchDiagnosticsV1>.size),
            (0..<225).contains(Int(run.search.move)),
            run.applied_policy.mode == config.mode,
            run.applied_policy.max_wall_time_ms == config.max_wall_time_ms,
            run.applied_policy.max_nodes == config.max_nodes,
            run.applied_policy.max_depth == config.max_depth,
            run.applied_policy.root_width == config.root_width,
            run.applied_policy.reply_width == config.reply_width,
            run.applied_policy.continuation_width == config.continuation_width,
            run.applied_policy.forced_line_depth == config.forced_line_depth,
            run.applied_policy.candidate_radius == config.candidate_radius
        else { return nil }

        return GomokuBotMove(
            index: Int(run.search.move),
            score: 0, // C ABI V2 does not expose normalized evaluation score.
            nodes: Int(clamping: run.search.nodes),
            elapsedMilliseconds: Int(max(0, run.search.elapsed_ms)),
            engineLabel: "ECLIPSE 2.0 \(model.family) · " +
                (useAdaptiveV3 ? "C++20 V3 自适应收敛" : "C++20 V2"),
            completedDepth: Int(run.search.completed_depth),
            nativeStopReason: run.search.reason,
            adaptiveEvidence: useAdaptiveV3
                ? EclipseAdaptiveStopEvidence(
                    stableCompletedRounds: Int(adaptiveRun.stable_rounds_observed),
                    nativeScoreGap: Int(adaptiveRun.native_score_gap),
                    complexityTier: Int(adaptiveRun.complexity_tier),
                    estimatedNextDepthMilliseconds:
                        Int(clamping: adaptiveRun.predicted_next_depth_ms)
                  ) : nil
        )
    }
}