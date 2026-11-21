import Foundation

#if DEBUG
/// Experimental research-only adapter used by XCTest to compare C++20 with
/// the native Swift ECLIPSE on the same device, board, rules and time budget.
/// Does NOT change the user's default bot or migrate any personal histories.
enum EclipseCppResearchFixture {
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
