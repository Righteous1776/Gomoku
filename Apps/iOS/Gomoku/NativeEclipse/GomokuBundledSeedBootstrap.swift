import Foundation

/// Explicitly verified first-launch bootstrap for the original offline
/// ECLIPSE seed. The primary journal always validates terminal outcome and
/// move legality again before committing; duplicates are never effective games.
enum GomokuBundledSeedBootstrap {
    struct Result: Sendable {
        let accepted: Int
        let duplicate: Int
        let rejected: Int
        let totalValid: Int
    }

    static func importVerifiedSeed(
        from file: URL,
        into journal: GomokuNativeTrainingJournal
    ) throws -> Result {
        // Bundled verifier checks original revision, checksum, legality and
        // terminal result. A failure must not insert even one record.
        let verified = try GomokuBundledNativeSeed.verify(from: file)
        let writer = try journal.makeBatchWriter()
        var accepted = 0
        var duplicate = 0
        var rejected = 0
        for (ordinal, game) in verified.enumerated() {
            if Task<Never, Never>.isCancelled { break }
            let composed = NativeGomokuSelfPlayGame(
                plies: game.plies,
                result: game.result,
                opening: Int(game.plies[0].action) ?? 112,
                botDecisions: max(0, game.plies.count - 1)
            )
            do {
                _ = try writer.append(composed, seed: ordinal)
                accepted += 1
            } catch GomokuNativeTrainingJournalError.duplicate {
                duplicate += 1
            } catch {
                rejected += 1
            }
        }
        return Result(
            accepted: accepted, duplicate: duplicate, rejected: rejected,
            totalValid: writer.totalValidCount
        )
    }
}
