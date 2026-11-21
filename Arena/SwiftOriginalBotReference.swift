import Foundation
#if os(Linux)
import Glibc
#else
import Darwin
#endif

/// Compiles and calls the original unmodified GomokuBot.swift, unlike the
/// smaller UnifiedSearch-only reference. Empty learning is explicit; not a
/// representation of the owner's trained private engine.
@main
struct SwiftOriginalGomokuBotReference {
    enum Failure: Error {
        case usage
        case invalidHistory
        case noMove
    }
    static func main() {
        do {
            try run()
        } catch {
            FileHandle.standardError.write(Data("SwiftOriginalBotReference ERROR: \(error)\n".utf8))
            exit(2)
        }
    }
    static func run() throws {
        var raw = ""
        var ms = 0
        var tier = BoardBotDifficulty.master
        let args = Array(CommandLine.arguments.dropFirst())
        var i = 0
        while i < args.count {
            if args[i] == "--best" && i+1 < args.count {
                raw = args[i+1]
                i += 2
            } else if args[i] == "--ms" && i+1 < args.count,
                      let number = Int(args[i+1]) {
                ms = number
                i += 2
            } else if args[i] == "--difficulty" && i+1 < args.count,
                      let level = BoardBotDifficulty(rawValue: args[i+1]) {
                tier = level
                i += 2
            } else {
                throw Failure.usage
            }
        }
        guard (1...20_000).contains(ms) else { throw Failure.usage }
        let moves = raw.isEmpty ? [] : raw.split(separator: ",")
        var board = GomokuState()
        for token in moves {
            guard let index = Int(token), (0..<225).contains(index),
                  board.apply(index: index, actor: board.currentPlayer)
            else { throw Failure.invalidHistory }
        }
        if board.winner != nil || board.isDraw {
            try output(["move": -1, "status": board.winner == .host ? 1 :
                        board.winner == .guest ? 2 : 3,
                        "nodes": 0, "elapsed_ms": 0, "difficulty": tier.rawValue,
                        "training": "empty-only"])
            return
        }
        let preset = GomokuBotBudget.forDifficulty(tier, profileLabel: "HIGH")
        let bounded = GomokuBotBudget(
            candidateRadius: preset.candidateRadius,
            rootCandidateLimit: preset.rootCandidateLimit,
            replyCandidateLimit: preset.replyCandidateLimit,
            continuationCandidateLimit: preset.continuationCandidateLimit,
            timeLimitMilliseconds: ms
        )
        let start = Date.timeIntervalSinceReferenceDate
        guard let decision = GomokuBot.chooseMove(
            in: board, for: board.currentPlayer,
            budget: bounded, learning: .empty,
            formationPreference: .disabled,
            difficultyRawValue: tier.rawValue
        ) else { throw Failure.noMove }
        var legal = board
        guard legal.apply(index: decision.index, actor: board.currentPlayer) else {
            throw Failure.noMove
        }
        let elapsed = max(0, Int((Date.timeIntervalSinceReferenceDate - start) * 1000))
        try output([
            "move": decision.index,
            "status": 0,
            "nodes": decision.nodes,
            "elapsed_ms": elapsed,
            "difficulty": tier.rawValue,
            "engine": decision.engineLabel ?? "OriginalSwiftGomokuBot",
            "training": "empty-only"
        ])
    }
    static func output(_ object: [String: Any]) throws {
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write(Data("\n".utf8))
    }
}
