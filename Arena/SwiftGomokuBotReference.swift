import Foundation
#if os(Linux)
import Glibc
#else
import Darwin
#endif

/// Runs the ACTUAL source of GomokuBot.chooseMove (R4/R6/R8, UnifiedSearch,
/// frozen R10 trees) as the headless reference. No private training records.
/// No simplified fake Swift implementation; the original production Bot code
/// is compiled alongside this adapter from the native Swift source tree.
@main
struct OriginalGomokuBotReference {
    enum ErrorCode: Error {
        case arguments
        case illegalMoveSequence
        case missingDecision
    }

    static func main() {
        do {
            try run()
        } catch {
            FileHandle.standardError.write(Data("GomokuBotReference ERROR: \(error)\n".utf8))
            exit(2)
        }
    }

    static func run() throws {
        let args = Array(CommandLine.arguments.dropFirst())
        guard (args.count == 4 || args.count == 6),
              args[0] == "--best", args[2] == "--ms",
              let ms = Int(args[3]), (1...20_000).contains(ms)
        else { throw ErrorCode.arguments }
        let tier: BoardBotDifficulty?
        if args.count == 6 {
            guard args[4] == "--tier",
                  let parsed = BoardBotDifficulty(rawValue: args[5])
            else { throw ErrorCode.arguments }
            tier = parsed
        } else {
            tier = nil
        }
        var state = GomokuState()
        for token in (args[1].isEmpty ? [] : args[1].split(separator: ",")) {
            guard let index = Int(token),
                  state.apply(index: index, actor: state.currentPlayer)
            else { throw ErrorCode.illegalMoveSequence }
        }
        let status = state.winner == .host ? 1 :
            state.winner == .guest ? 2 : state.isDraw ? 3 : 0
        if status != 0 {
            try output(["move": -1, "status": status])
            return
        }

        // The research Arena controls the same ms budget on both engines.
        // The other native strength / tier configurations are tested later
        // with original seven-tier budgets on matched CPU/device classes.
        let budget: GomokuBotBudget
        if let tier {
            budget = GomokuBotBudget.forDifficulty(tier, profileLabel: "HIGH")
            // The research opponent receives the identical wall-clock budget
            // from the source policy, not a guessed or silently capped preset.
            guard ms == budget.timeLimitMilliseconds else {
                throw ErrorCode.arguments
            }
        } else {
            budget = GomokuBotBudget(
                candidateRadius: 2, rootCandidateLimit: 18,
                replyCandidateLimit: 10, continuationCandidateLimit: 8,
                timeLimitMilliseconds: ms
            )
        }
        let started = Date.timeIntervalSinceReferenceDate
        guard let decision = GomokuBot.chooseMove(
            in: state, for: state.currentPlayer, budget: budget,
            learning: .empty, formationPreference: .disabled,
            difficultyRawValue: tier?.rawValue
        ) else { throw ErrorCode.missingDecision }
        let elapsed = Int(max(0,
            (Date.timeIntervalSinceReferenceDate - started) * 1_000))
        try output([
            "move": decision.index, "status": 0,
            "elapsed_ms": elapsed,
            "nodes": decision.nodes,
            "tier": tier?.rawValue ?? "custom",
            "budget_ms": budget.timeLimitMilliseconds,
            "engine": "Original native Swift GomokuBot (empty personal learning)"
        ])
    }

    private static func output(_ value: [String: Any]) throws {
        let data = try JSONSerialization.data(
            withJSONObject: value, options: [.sortedKeys])
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write(Data("\n".utf8))
    }
}
