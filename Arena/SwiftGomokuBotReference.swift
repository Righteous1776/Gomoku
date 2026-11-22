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
        guard (args.count == 4 || args.count == 6 || args.count == 7),
              args[0] == "--best", args[2] == "--ms",
              let ms = Int(args[3]), ms >= 0
        else { throw ErrorCode.arguments }
        let traceRequested = args.count == 7 && args[6] == "--trace"
        guard args.count != 7 || traceRequested else { throw ErrorCode.arguments }
        let tier: BoardBotDifficulty?
        if args.count >= 6 {
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

        // The research Arena can request any nonnegative trainer-selected ms;
        // zero means no fixed wall deadline. Legacy --tier cases remain exact
        // historical references, not ceilings for new model checkpoints.
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
        var traceRows = [[String: Any]]()
        guard let decision = GomokuBot.chooseMove(
            in: state, for: state.currentPlayer, budget: budget,
            learning: .empty, formationPreference: .disabled,
            difficultyRawValue: tier?.rawValue,
            onSearchTrace: { trace in
                guard traceRequested,
                      trace.phase == .deepening || trace.phase == .complete
                else { return }
                traceRows.append([
                    "phase": String(describing: trace.phase),
                    "completed_depth": trace.completedDepth,
                    "nodes": trace.nodes,
                    "root_candidates": trace.rootCandidates,
                    "move": trace.selectedIndex ?? -1,
                    "score": trace.score as Any? ?? NSNull(),
                    "pv": trace.variation,
                    "rule": trace.rule
                ])
            }
        ) else { throw ErrorCode.missingDecision }
        let elapsed = Int(max(0,
            (Date.timeIntervalSinceReferenceDate - started) * 1_000))
        var response: [String: Any] = [
            "move": decision.index, "status": 0,
            "elapsed_ms": elapsed,
            "nodes": decision.nodes,
            "tier": tier?.rawValue ?? "custom",
            "budget_ms": budget.timeLimitMilliseconds,
            "engine": "Original native Swift GomokuBot (empty personal learning)"
        ]
        if traceRequested {
            response["schema"] = "eclipse.zenith6x.teacher-decision.v1"
            response["rules"] = "freestyle-15"
            response["teacher_config"] = "zenith: HIGH profile; empty personal learning; no formation guidance"
            response["trace"] = traceRows
            response["trace_is_proven_win"] = false
            response["completed_depth"] = traceRows.map { $0["completed_depth"] as? Int ?? 0 }.max() ?? 0
            response["source"] = "compiled original Swift GomokuBot; direct decisions not fabricated"
        }
        try output(response)
    }

    private static func output(_ value: [String: Any]) throws {
        let data = try JSONSerialization.data(
            withJSONObject: value, options: [.sortedKeys])
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write(Data("\n".utf8))
    }
}
