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
