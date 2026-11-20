import Foundation

// Adapted Gomoku-only learning interface from AdaptiveBoardLearning.swift.
// Full persistent repertoire store requires separate controlled data migration.
struct AdaptiveBoardLearningSnapshot: Sendable {
    static let empty = AdaptiveBoardLearningSnapshot(
        preferences: [:],
        rootAdjustments: [:],
        predictedHumanReplies: [:],
        trainingLevel: 0
    )

    fileprivate let preferences: [String: [String: Int]]
    fileprivate let rootAdjustments: [String: Int]
    fileprivate let predictedHumanReplies: [String: AdaptiveBoardPrediction]
    /// Bounded compute reinforcement derived from retained local evidence. This
    /// is independent of the uncapped on-disk history and is safe on old devices.
    let trainingLevel: Int

    func bonus(position: String, action: String) -> Int {
        preferences[position]?[action] ?? 0
    }

    /// Outcome-aware sequence memory. Repeating a line that lost (or was repeatedly
    /// abandoned) is penalised, while lines that held up are reinforced.
    func rootAdjustment(action: String) -> Int {
        rootAdjustments[action] ?? 0
    }

    /// The player's most likely next move after a candidate AI move.
    func predictedHumanReply(afterAIAction action: String) -> AdaptiveBoardPrediction? {
        predictedHumanReplies[action]
    }

    var hasSequenceEvidence: Bool {
        !rootAdjustments.isEmpty || !predictedHumanReplies.isEmpty
    }
}

extension AdaptiveBoardLearningSnapshot {
    /// The self-play archive is independent from the player's human-match
    /// sequence history. Only a small portion of its positional preferences
    /// enters native AI move ranking. It cannot forge human reply predictions.
    func incorporatingNativeSelfPlay(
        _ training: AdaptiveBoardLearningSnapshot,
        completedGames: Int
    ) -> AdaptiveBoardLearningSnapshot {
        guard completedGames > 0 else { return self }
        var blended = preferences
        for (position, actions) in training.preferences where position.hasPrefix("g:") {
            var combined = blended[position] ?? [:]
            for (action, value) in actions {
                let contribution = max(-30, min(120, value / 8))
                combined[action] = max(-180, min(900, (combined[action] ?? 0) + contribution))
            }
            blended[position] = combined
        }
        return AdaptiveBoardLearningSnapshot(
            preferences: blended,
            rootAdjustments: rootAdjustments,
            predictedHumanReplies: predictedHumanReplies,
            trainingLevel: trainingLevel
        )
    }
}

struct AdaptiveBoardPrediction: Equatable, Sendable {
    let action: String
    let evidence: Int
}

struct DeveloperFormationInfluence: Sendable {
    static let empty = DeveloperFormationInfluence(rootAdjustments: [:], predictedHumanReplies: [:], matchedLessonNames: [])
    let rootAdjustments: [String: Int]
    let predictedHumanReplies: [String: AdaptiveBoardPrediction]
    let matchedLessonNames: [String]
}

extension AdaptiveBoardLearningSnapshot {
    func applying(_ influence: DeveloperFormationInfluence) -> AdaptiveBoardLearningSnapshot {
        var roots = rootAdjustments
        for (action, bonus) in influence.rootAdjustments {
            roots[action, default: 0] = min(2_400, max(-1_200, roots[action, default: 0] + bonus))
        }
        var replies = predictedHumanReplies
        for (action, prediction) in influence.predictedHumanReplies {
            if let current = replies[action], current.evidence > prediction.evidence { continue }
            replies[action] = prediction
        }
        return AdaptiveBoardLearningSnapshot(
            preferences: preferences,
            rootAdjustments: roots,
            predictedHumanReplies: replies,
            trainingLevel: trainingLevel
        )
    }
}

enum AdaptiveBoardPosition {
    static func gomoku(_ state: GomokuState) -> String {
        var bytes: [UInt8] = [state.currentPlayer == .host ? 1 : 2]
        bytes.reserveCapacity(GomokuState.size * GomokuState.size + 1)
        for index in 0..<(GomokuState.size * GomokuState.size) {
            bytes.append(UInt8(state.value(at: index)))
        }
        return "g:" + fnv64(bytes)
    }

    private static func fnv64(_ bytes: [UInt8]) -> String {
        var value: UInt64 = 14_695_981_039_346_656_037
        for byte in bytes { value ^= UInt64(byte); value &*= 1_099_511_628_211 }
        return String(value, radix: 16)
    }
}

struct AdaptiveBoardPly: Equatable, Sendable {
    let position: String
    let action: String
    let actor: MiniGamePlayer
}

enum AdaptiveBoardGameResult: String, Codable, Sendable {
    case humanWon
    case aiWon
    case draw
    case unfinished

    fileprivate var aiReward: Int {
        switch self {
        case .aiWon: return 2
        case .humanWon: return -2
        case .draw, .unfinished: return 0
        }
    }
}
