import Foundation

#if DEBUG
/// Experimental research-only adapter used by XCTest to compare C++20 with
/// the native Swift ECLIPSE on the same device, board, rules and time budget.
/// Does NOT change the user's default bot or migrate any personal histories.
enum EclipseCppResearchFixture {
    static func bestMoveWithRootPolicy(
        history: [Int], milliseconds: Int,
        allowed: Set<Int>, rootBonuses: [Int: Int]
    ) -> Int? {
        guard let engine = eg_create() else { return nil }
        defer { eg_destroy(engine) }
        for index in history {
            guard (0..<225).contains(index),
                  eg_play(engine, Int32(index)) == 1 else { return nil }
        }
        guard allowed.allSatisfy({ (0..<225).contains($0) }),
              rootBonuses.allSatisfy({ (0..<225).contains($0.key) &&
                  (-2000...2000).contains($0.value) }) else { return nil }
        var allowedCells = [UInt8](repeating: 0, count: 225)
        for index in allowed { allowedCells[index] = 1 }
        var bonuses = [Int32](repeating: 0, count: 225)
        for (index, value) in rootBonuses { bonuses[index] = Int32(value) }
        var metrics = EGSearchDiagnosticsV1()
        metrics.size_bytes = UInt32(MemoryLayout<EGSearchDiagnosticsV1>.size)
        let accepted = allowedCells.withUnsafeBufferPointer { allowedBuffer in
            bonuses.withUnsafeBufferPointer { bonusesBuffer in
                eg_best_move_root_policy_v1(
                    engine, Int32(milliseconds),
                    allowedBuffer.baseAddress, Int32(allowedBuffer.count),
                    bonusesBuffer.baseAddress, Int32(bonusesBuffer.count),
                    &metrics
                )
            }
        }
        guard accepted == 1, metrics.move >= 0 else { return nil }
        return Int(metrics.move)
    }

    /// R17 on-device research execution of actual C++ trainer policy V2.
    /// This adapter does not implement checkpoint loading or alter the
    /// production Swift opponent. No personal history is logged/transferred.
    struct TrainerRun {
        let move: Int
        let elapsedMilliseconds: Int
        let nodes: UInt64
        let completedDepth: Int
        let appliedPolicyDigest: String
    }

    static func runTrainerComputeV2(
        history: [Int],
        policy: EclipseTrainerComputePolicy,
        allowedRoots: Set<Int>? = nil,
        rootBonuses: [Int: Int] = [:]
    ) -> TrainerRun? {
        guard policy.isValid, let digest = policy.sha256,
              let engine = eg_create() else { return nil }
        defer { eg_destroy(engine) }
        for index in history {
            guard (0..<225).contains(index),
                  eg_play(engine, Int32(index)) == 1 else { return nil }
        }
        guard eg_status(engine) == 0 else { return nil }

        var config = EGComputePolicyV2()
        config.size_bytes = UInt32(MemoryLayout<EGComputePolicyV2>.size)
        config.mode = policy.mode == .adaptive ? 0 : 1
        config.max_wall_time_ms = Int64(policy.maxWallTimeMilliseconds ?? 0)
        config.max_nodes = UInt64(policy.maxNodes ?? 0)
        config.max_depth = Int32(policy.maxDepth)
        config.root_width = Int32(policy.rootWidth)
        config.reply_width = Int32(policy.replyWidth)
        config.continuation_width = Int32(policy.continuationWidth)
        config.forced_line_depth = Int32(policy.forcedLineDepth)
        config.candidate_radius = Int32(policy.candidateRadius)

        var result = EGComputeRunV2()
        result.size_bytes = UInt32(MemoryLayout<EGComputeRunV2>.size)
        let ok: Int32
        if let allowedRoots {
            guard allowedRoots.allSatisfy({ (0..<225).contains($0) }),
                  rootBonuses.allSatisfy({
                      (0..<225).contains($0.key) &&
                      (-2000...2000).contains($0.value)
                  }) else { return nil }
            var allowed = [UInt8](repeating: 0, count: 225)
            for root in allowedRoots { allowed[root] = 1 }
            var bonus = [Int32](repeating: 0, count: 225)
            for (root, value) in rootBonuses { bonus[root] = Int32(value) }
            ok = allowed.withUnsafeBufferPointer { a in
                bonus.withUnsafeBufferPointer { b in
                    eg_analyze_compute_policy_v2(
                        engine, &config,
                        a.baseAddress, Int32(a.count),
                        b.baseAddress, Int32(b.count), &result
                    )
                }
            }
        } else {
            guard rootBonuses.isEmpty else { return nil }
            ok = eg_analyze_compute_policy_v2(
                engine, &config, nil, 0, nil, 0, &result
            )
        }
        guard ok == 1, result.size_bytes == UInt32(MemoryLayout<EGComputeRunV2>.size),
              result.search.move >= 0, result.search.move < 225,
              result.search.size_bytes ==
                  UInt32(MemoryLayout<EGSearchDiagnosticsV1>.size),
              result.applied_policy.size_bytes == config.size_bytes,
              result.applied_policy.mode == config.mode,
              result.applied_policy.max_wall_time_ms == config.max_wall_time_ms,
              result.applied_policy.max_nodes == config.max_nodes,
              result.applied_policy.max_depth == config.max_depth,
              result.applied_policy.root_width == config.root_width,
              result.applied_policy.reply_width == config.reply_width,
              result.applied_policy.continuation_width ==
                  config.continuation_width,
              result.applied_policy.forced_line_depth == config.forced_line_depth,
              result.applied_policy.candidate_radius == config.candidate_radius
        else { return nil }
        return TrainerRun(
            move: Int(result.search.move),
            elapsedMilliseconds: Int(result.search.elapsed_ms),
            nodes: result.search.nodes,
            completedDepth: Int(result.search.completed_depth),
            appliedPolicyDigest: digest
        )
    }

    static func bestMove(history: [Int], milliseconds: Int) -> Int? {
        guard let engine = eg_create() else { return nil }
        defer { eg_destroy(engine) }
        for index in history {
            guard (0..<225).contains(index),
                  eg_play(engine, Int32(index)) == 1 else { return nil }
        }
        let move = eg_best_move(engine, Int32(milliseconds))
        return move >= 0 ? Int(move) : nil
    }
}
#endif
