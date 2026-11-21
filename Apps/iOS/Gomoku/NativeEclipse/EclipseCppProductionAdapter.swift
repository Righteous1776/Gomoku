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
final class EclipseCppProductionAdapter: @unchecked Sendable {
    private let engine: OpaquePointer
    private let checkpointSHA256: String

    private init?(history: [Int], checkpointSHA256: String) {
        guard let created = eg_create() else { return nil }
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

    /// Runtime dispatch authority: real C++ loaded model and trainer handoff
    /// must agree byte-for-byte. Merely having a C++ ABI does not suffice.
    static func make(
        history: [Int],
        trainer: EclipseVerifiedTrainerExecution
    ) -> EclipseCppProductionAdapter? {
        guard eg_compute_policy_abi_version() == 2,
              loadedCheckpointSHA256() == trainer.checkpointSHA256
        else { return nil }
        return EclipseCppProductionAdapter(
            history: history, checkpointSHA256: trainer.checkpointSHA256
        )
    }

    /// Safe to invoke concurrently with a running analyze call on this
    /// instance; the C ABI only permits atomic cancellation during search.
    /// Do NOT play, reset, or destroy the native engine while search runs.
    func cancel() {
        eg_cancel_search_v2(engine)
    }

    /// Runs the native C++ evaluator once. No app-specific 5.7s/20s limit,
    /// no separate model budget overriding the Training Agent's policy.
    /// The search always executes off the MainActor.
    func decide(
        policy: EclipseTrainerComputePolicy
    ) -> GomokuBotMove? {
        guard policy.isValid, let actual = Self.loadedCheckpointSHA256(),
              actual == checkpointSHA256 else { return nil }
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

        var run = EGComputeRunV2()
        run.size_bytes = UInt32(MemoryLayout<EGComputeRunV2>.size)
        guard eg_analyze_compute_policy_v2(
            engine, &config, nil, 0, nil, 0, &run
        ) == 1,
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
            engineLabel: "ECLIPSE C++20 V2",
            completedDepth: Int(run.search.completed_depth)
        )
    }
}