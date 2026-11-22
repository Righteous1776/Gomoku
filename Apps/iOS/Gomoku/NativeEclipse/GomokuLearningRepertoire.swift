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
        let validLegacyGames: Int
        let invalidLegacyFiles: Int
    }

    static func build(
        journalDirectory: URL,
        archiveDirectory: URL,
        currentMoves: [VeilGomokuMatchArchive.Move],
        humanStone: UInt8,
        includeNativeSelfPlay: Bool = true,
        importedLegacyDirectory: URL? = nil,
        localEvidence: GomokuLocalMatchEvidence? = nil,
        focusOnCurrentPosition: Bool = false
    ) -> BuildReport {
        // On 2GB devices only the current root matters to C++ RootPolicy.
        // Still verify and replay EVERY original game; never truncate or
        // alter the archive, evidence counters, outcome, or reply provenance.
        // Other devices retain the complete historical snapshot.
        let targetPosition: String? = {
            guard focusOnCurrentPosition else { return nil }
            var replay = GomokuState()
            for move in currentMoves {
                guard replay.apply(index: move.index,
                                   actor: replay.currentPlayer) else {
                    return nil
                }
            }
            return AdaptiveBoardPosition.gomoku(replay)
        }()
        var humanStats: [String: [String: Stat]] = [:]
        var nativeStats: [String: [String: Stat]] = [:]
        var humanGames = 0
        var roots: [String: Int] = [:]
        var replies: [String: [String: Int]] = [:]

        let archive = VeilGomokuMatchArchive(directory: archiveDirectory)
        let proof = localEvidence ?? GomokuLocalMatchEvidence(
            directory: archiveDirectory.deletingLastPathComponent()
                .appendingPathComponent("VerifiedLocalLearningV1", isDirectory: true)
        )
        // Stream each validated game once; no O(N log N) re-sort per page
        // during every AI turn. Imported reference matches are still excluded.
        for match in archive.verifiedMatches() {
                // Files-imported reference matches may be replayable but are
                // not evidence that the player actually completed the game.
                // Only HMAC-attested *local* records influence search weights.
                guard proof.isVerifiedLocal(match) else { continue }
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
                    if targetPosition == nil || position == targetPosition {
                        var options = humanStats[position] ?? [:]
                        var stat = options[action] ?? Stat()
                        stat.add(result, byAI: byAI)
                        options[action] = stat
                        humanStats[position] = options
                    }
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

        // The imported legacy book is not a self-play counter. Its entries
        // were individually replayed and stored in the standalone Gomoku
        // namespace by GomokuLegacyLearningImporter.
        let legacyFolder = importedLegacyDirectory
            ?? archiveDirectory.deletingLastPathComponent()
                .appendingPathComponent("ImportedLegacyLearningV1", isDirectory: true)
        let legacyVerification = GomokuNativeTrainingJournal(directory: legacyFolder).inspect { record in
            humanGames += 1
            // The journal's outcome is intentionally color-oriented for replay
            // verification. Imported owner identity must be mapped separately.
            let ownerStone = record.humanStone ?? 1
            let ownerOutcome: AdaptiveBoardGameResult
            switch record.outcome {
            case .draw: ownerOutcome = .draw
            case .humanWon: ownerOutcome = ownerStone == 1 ? .humanWon : .aiWon
            case .aiWon: ownerOutcome = ownerStone == 2 ? .humanWon : .aiWon
            case .unfinished: return
            }
            var game = GomokuState()
            for index in record.moves {
                let position = AdaptiveBoardPosition.gomoku(game)
                let stone: UInt8 = game.currentPlayer == .host ? 1 : 2
                let byAI = stone != ownerStone
                if targetPosition == nil || position == targetPosition {
                    var options = humanStats[position] ?? [:]
                    var stat = options[String(index)] ?? Stat()
                    stat.add(ownerOutcome, byAI: byAI)
                    options[String(index)] = stat
                    humanStats[position] = options
                }
                _ = game.apply(index: index, actor: game.currentPlayer)
            }
            let nextStone: UInt8 = currentMoves.count.isMultiple(of: 2) ? 1 : 2
            guard ownerStone == humanStone,
                  nextStone != ownerStone,
                  record.moves.count > currentMoves.count,
                  Array(record.moves.prefix(currentMoves.count)) == currentMoves.map(\.index) else { return }
            let choice = String(record.moves[currentMoves.count])
            roots[choice, default: 0] += ownerOutcome == .aiWon ? 420
                : ownerOutcome == .humanWon ? -620 : -60
            if record.moves.count > currentMoves.count + 1 {
                let reply = String(record.moves[currentMoves.count + 1])
                replies[choice, default: [:]][reply, default: 0] +=
                    ownerOutcome == .humanWon ? 4 : 1
            }
        }

        let journal = GomokuNativeTrainingJournal(directory: journalDirectory)
        let verification = journal.inspect { record in
            guard includeNativeSelfPlay else { return }
            var state = GomokuState()
            for actionIndex in record.moves {
                let position = AdaptiveBoardPosition.gomoku(state)
                let action = String(actionIndex)
                if targetPosition == nil || position == targetPosition {
                    var options = nativeStats[position] ?? [:]
                    var stat = options[action] ?? Stat()
                    stat.add(record.outcome, byAI: state.currentPlayer == .guest)
                    options[action] = stat
                    nativeStats[position] = options
                }
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
            validHumanGames: humanGames,
            validLegacyGames: legacyVerification.accepted,
            invalidLegacyFiles: legacyVerification.invalid
        )
    }
}
