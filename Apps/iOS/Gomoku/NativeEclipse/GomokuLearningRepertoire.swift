import Foundation

/// Builds actual, outcome-aware GomokuBot preferences from validated on-disk
/// games. Never reads VeilLink's private sandbox or any Xiangqi namespace.
/// The current implementation streams records, without trusting a UI counter.
/// A persistent indexed store is a separate scale/performance acceptance gate.
enum GomokuLearningRepertoire {
    private struct Stat {
        var aiCount = 0
        var opponentCount = 0
        var aiReward = 0
        var opponentReward = 0

        mutating func add(_ outcome: AdaptiveBoardGameResult, byAI: Bool) {
            let value: Int
            switch outcome {
            case .aiWon: value = 2
            case .humanWon: value = -2
            case .draw, .unfinished: value = 0
            }
            if byAI {
                aiCount = min(65_535, aiCount + 1)
                aiReward = max(-32_000, min(32_000, aiReward + value))
            } else {
                opponentCount = min(65_535, opponentCount + 1)
                opponentReward = max(-32_000, min(32_000, opponentReward + value))
            }
        }

        func bonus() -> Int {
            // The source's two actor roles have different priors: bot decisions
            // are reinforced by outcome, opponent actions inform reply order.
            let raw = aiCount * 18 + aiReward * 55
                + opponentCount * 42 + max(0, -opponentReward) * 20
            return min(900, max(-180, raw))
        }
    }

    struct BuildReport {
        let snapshot: AdaptiveBoardLearningSnapshot
        let validNativeGames: Int
        let invalidNativeFiles: Int
        let duplicateNativeFiles: Int
        let validHumanGames: Int
    }

    static func build(
        journalDirectory: URL,
        archiveDirectory: URL,
        currentMoves: [VeilGomokuMatchArchive.Move],
        humanStone: UInt8,
        includeNativeSelfPlay: Bool = true
    ) -> BuildReport {
        var humanStats: [String: [String: Stat]] = [:]
        var nativeStats: [String: [String: Stat]] = [:]
        var humanGames = 0
        var roots: [String: Int] = [:]
        var replies: [String: [String: Int]] = [:]

        let archive = VeilGomokuMatchArchive(directory: archiveDirectory)
        var offset = 0
        // The archive validates each game before returning it; never treat an
        // interrupted game as a completed outcome or training evidence.
        while let page = try? archive.page(offset: offset, limit: 50) {
            for match in page.matches {
                let result: AdaptiveBoardGameResult
                switch match.status {
                case .aiWon: result = .aiWon
                case .humanWon: result = .humanWon
                case .draw: result = .draw
                case .interrupted, .playing: continue
                }
                humanGames += 1
                var state = GomokuState()
                for ply in match.moves {
                    let position = AdaptiveBoardPosition.gomoku(state)
                    let action = String(ply.index)
                    let byAI = ply.stone != match.humanStone
                    var options = humanStats[position] ?? [:]
                    var stat = options[action] ?? Stat()
                    stat.add(result, byAI: byAI)
                    options[action] = stat
                    humanStats[position] = options
                    // Archive's read() and validate() already confirmed legality.
                    _ = state.apply(index: ply.index, actor: state.currentPlayer)
                }
                if match.humanStone == humanStone,
                   match.moves.count > currentMoves.count,
                   Array(match.moves.prefix(currentMoves.count)) == currentMoves {
                    let next = match.moves[currentMoves.count]
                    if next.stone != match.humanStone {
                        let action = String(next.index)
                        let outcome = result == .aiWon ? 420 : result == .humanWon ? -620 : -60
                        roots[action, default: 0] += outcome
                        if match.moves.count > currentMoves.count + 1 {
                            let reply = match.moves[currentMoves.count + 1]
                            if reply.stone == match.humanStone {
                                let weight = result == .humanWon ? 4 : 1
                                replies[action, default: [:]][String(reply.index), default: 0] += weight
                            }
                        }
                    }
                }
            }
            guard let next = page.nextOffset, next > offset else { break }
            offset = next
        }

        let journal = GomokuNativeTrainingJournal(directory: journalDirectory)
        let verification = journal.inspect { record in
            guard includeNativeSelfPlay else { return }
            var state = GomokuState()
            for actionIndex in record.moves {
                let position = AdaptiveBoardPosition.gomoku(state)
                let action = String(actionIndex)
                var options = nativeStats[position] ?? [:]
                var stat = options[action] ?? Stat()
                stat.add(record.outcome, byAI: state.currentPlayer == .guest)
                options[action] = stat
                nativeStats[position] = options
                _ = state.apply(index: actionIndex, actor: state.currentPlayer)
            }
        }

        func preferences(_ stats: [String: [String: Stat]]) -> [String: [String: Int]] {
            stats.mapValues { actions in
                actions.mapValues { $0.bonus() }
            }
        }

        var predictions: [String: AdaptiveBoardPrediction] = [:]
        for (aiMove, actions) in replies {
            if let best = actions.max(by: {
                $0.value == $1.value ? $0.key > $1.key : $0.value < $1.value
            }) {
                predictions[aiMove] = AdaptiveBoardPrediction(action: best.key, evidence: best.value)
            }
        }
        let effectiveNativeGames = includeNativeSelfPlay ? verification.accepted : 0
        let level = min(8, (humanGames + effectiveNativeGames) / 3
            + (humanStats.count + nativeStats.count) / 220)
        let human = AdaptiveBoardLearningSnapshot(
            preferences: preferences(humanStats),
            rootAdjustments: roots.mapValues { min(1_200, max(-1_200, $0)) },
            predictedHumanReplies: predictions,
            trainingLevel: level
        )
        let native = AdaptiveBoardLearningSnapshot(
            preferences: preferences(nativeStats),
            rootAdjustments: [:], predictedHumanReplies: [:],
            trainingLevel: 0
        )
        return BuildReport(
            snapshot: includeNativeSelfPlay
                ? human.incorporatingNativeSelfPlay(native, completedGames: verification.accepted)
                : human,
            validNativeGames: verification.accepted,
            invalidNativeFiles: verification.invalid,
            duplicateNativeFiles: verification.duplicates,
            validHumanGames: humanGames
        )
    }
}
