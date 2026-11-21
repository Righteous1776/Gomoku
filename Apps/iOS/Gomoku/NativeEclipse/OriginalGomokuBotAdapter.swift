import Foundation

/// Original, mandatory-tactical-gated GomokuBot bridge for independent app.
enum OriginalGomokuBotAdapter {
    static func choose(
        moveHistory: [Int],
        difficulty: BoardBotDifficulty = .balanced,
        profileLabel: String = "HIGH",
        learning: AdaptiveBoardLearningSnapshot = .empty,
        formation: GomokuFormationPreference = .disabled
    ) -> GomokuBotMove? {
        var state = GomokuState()
        for index in moveHistory {
            guard state.apply(index: index, actor: state.currentPlayer) else { return nil }
        }
        guard state.winner == nil, !state.isDraw else { return nil }
        let budget = GomokuBotBudget.forDifficulty(
            difficulty, profileLabel: profileLabel
        ).reinforced(by: learning.trainingLevel)
        return GomokuBot.chooseMove(
            in: state, for: state.currentPlayer,
            budget: budget, learning: learning, formationPreference: formation,
            difficultyRawValue: difficulty.rawValue
        )
    }
}
