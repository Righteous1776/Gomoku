import Foundation

/// V9 runtime bridge for VALIDATED local learning and owner-configured
/// formations. This is NOT a new trained model or an imported private game.
/// Only bounded current-root preferences cross the C++ V2 ABI. Full board
/// legality and immediate win/block/fork certification remain C++ authority.
struct EclipseCppRootLearningPolicy: Sendable {
    let allowed: [UInt8]
    let bonuses: [Int32]

    static func build(
        state: GomokuState,
        player: MiniGamePlayer,
        learning: AdaptiveBoardLearningSnapshot,
        formation: GomokuFormationPreference
    ) -> EclipseCppRootLearningPolicy {
        // Do not truncate the C++ candidate frontier here: the native search
        // performs the final tactical gate BEFORE applying these preferences.
        let permitted = [UInt8](repeating: 1, count: 225)
        var values = [Int32](repeating: 0, count: 225)
        let position = AdaptiveBoardPosition.gomoku(state)
        let urgent = formation.enabled &&
            GomokuFormationPreference.opponentHasImmediateWin(
                in: state, player: player
            )
        for index in 0..<225 where state.value(at: index) == 0 {
            let action = String(index)
            let prior = learning.bonus(position: position, action: action)
            let sequence = learning.rootAdjustment(action: action)
            let shape = formation.bonus(
                index: index, state: state, player: player,
                urgentDefense: urgent
            )
            values[index] = Int32(max(-2_000, min(2_000,
                prior + sequence + shape
            )))
        }
        return EclipseCppRootLearningPolicy(
            allowed: permitted, bonuses: values
        )
    }

    var isValid: Bool {
        allowed.count == 225 && bonuses.count == 225
            && allowed.allSatisfy { $0 <= 1 }
            && bonuses.allSatisfy { (-2_000...2_000).contains($0) }
    }
}
