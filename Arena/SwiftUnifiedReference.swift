import Foundation
#if os(Linux)
import Glibc
#else
import Darwin
#endif

/// Headless, actual Swift UnifiedSearch test harness.
/// The search code is compiled directly from Apps/iOS/Gomoku/NativeEclipse.
/// This executable is NOT an independently reimplemented "Swift oracle".
@main
struct SwiftEclipseReference {
    enum Failure: Error {
        case usage
        case illegalHistory
        case invalidPosition
        case noDecision
    }

    static func main() {
        do {
            try execute()
        } catch {
            FileHandle.standardError.write(Data("SwiftEclipseReference ERROR: \(error)\n".utf8))
            exit(2)
        }
    }

    static func execute() throws {
        let args = Array(CommandLine.arguments.dropFirst())
        guard args.count == 4,
              args[0] == "--best",
              args[2] == "--ms",
              let millis = Int(args[3]), (1...20_000).contains(millis)
        else { throw Failure.usage }

        let raw = args[1].isEmpty ? [] : args[1].split(separator: ",")
        var board = GomokuState()
        for token in raw {
            guard let index = Int(token), (0..<225).contains(index),
                  board.apply(index: index, actor: board.currentPlayer)
            else { throw Failure.illegalHistory }
        }
        guard board.winner == nil, !board.isDraw else {
            let result: [String: Any] = [
                "move": -1, "status": board.winner == .host ? 1 :
                    board.winner == .guest ? 2 : 3,
                "depth": 0, "nodes": 0, "rule": "terminal"
            ]
            try output(result)
            return
        }
        let cells = (0..<225).map { UInt8(max(0, board.value(at: $0))) }
        let toMove: UInt8 = board.currentPlayer == .host ? 1 : 2
        guard let position = VeilGomokuUnifiedSearch.Position(
            cells: cells, toMove: toMove
        ) else { throw Failure.invalidPosition }
        var limits = VeilGomokuUnifiedSearch.Limits()
        limits.maxMilliseconds = millis
        limits.maxNodes = max(2_000, min(180_000, millis * 125))
        limits.maxDepth = 5
        limits.width = 18
        limits.candidateRadius = 2
        limits.forcedLineDepth = 5

        let started = Date.timeIntervalSinceReferenceDate
        guard let decision = VeilGomokuUnifiedSearch.decide(
            position, limits: limits, trainedPolicy: true
        ) else { throw Failure.noDecision }
        let elapsed = Int(max(0, (Date.timeIntervalSinceReferenceDate - started) * 1000))
        try output([
            "move": decision.index,
            "status": 0,
            "depth": decision.completedDepth,
            "nodes": decision.nodes,
            "rule": decision.rule,
            "elapsed_ms": elapsed
        ])
    }

    private static func output(_ obj: [String: Any]) throws {
        let data = try JSONSerialization.data(withJSONObject: obj, options: [.sortedKeys])
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write(Data("\n".utf8))
    }
}
