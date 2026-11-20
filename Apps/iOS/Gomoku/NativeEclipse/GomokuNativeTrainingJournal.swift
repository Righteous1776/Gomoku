import Foundation

/// Only real, fully replay-validated native self-play games are stored.
struct GomokuNativeTrainingRecord: Codable {
    static let version = 1
    let version: Int
    let id: UUID
    let createdAt: Date
    let seed: Int
    let moves: [Int]
    let outcome: AdaptiveBoardGameResult
}

enum GomokuNativeTrainingJournalError: LocalizedError {
    case invalidGame, corrupted
    var errorDescription: String? {
        switch self {
        case .invalidGame: return "本局训练未完成或棋谱复验失败，未计入训练次数。"
        case .corrupted: return "训练档案校验失败，原文件已保留。"
        }
    }
}

/// Per-game JSON, no artificial count cap and no VeilLink messenger dependency.
/// Retains the source game evidence; learning feedback into the AI is a separate
/// parity/release gate, NOT falsely implied by writing a training file.
final class GomokuNativeTrainingJournal {
    let directory: URL
    init(directory: URL? = nil) {
        if let directory { self.directory = directory }
        else {
            let support = FileManager.default.urls(
                for: .applicationSupportDirectory, in: .userDomainMask
            ).first ?? FileManager.default.temporaryDirectory
            self.directory = support
                .appendingPathComponent("Gomoku", isDirectory: true)
                .appendingPathComponent("NativeSelfPlayV1", isDirectory: true)
        }
    }

    func count() -> Int {
        guard let names = try? FileManager.default.contentsOfDirectory(
            atPath: directory.path
        ) else { return 0 }
        return names.filter { name in
            name.hasSuffix(".json")
                && UUID(uuidString: String(name.dropLast(5))) != nil
        }.count
    }

    @discardableResult
    func append(_ game: NativeGomokuSelfPlayGame, seed: Int) throws -> URL {
        guard game.completed, !game.plies.isEmpty,
              game.plies.count <= 225 else {
            throw GomokuNativeTrainingJournalError.invalidGame
        }
        var replay = GomokuState()
        var indices: [Int] = []
        indices.reserveCapacity(game.plies.count)
        for ply in game.plies {
            guard let index = Int(ply.action),
                  (0..<225).contains(index),
                  ply.actor == replay.currentPlayer,
                  ply.position == AdaptiveBoardPosition.gomoku(replay),
                  replay.apply(index: index, actor: ply.actor) else {
                throw GomokuNativeTrainingJournalError.invalidGame
            }
            indices.append(index)
        }
        guard replay.winner != nil || replay.isDraw else {
            throw GomokuNativeTrainingJournalError.invalidGame
        }
        let id = UUID()
        let record = GomokuNativeTrainingRecord(
            version: GomokuNativeTrainingRecord.version, id: id,
            createdAt: Date(), seed: seed, moves: indices,
            outcome: game.result
        )
        try FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true
        )
        let path = directory.appendingPathComponent(id.uuidString + ".json")
        var options: Data.WritingOptions = [.atomic]
        #if canImport(UIKit)
        options.insert(.completeFileProtectionUntilFirstUserAuthentication)
        #endif
        try JSONEncoder().encode(record).write(to: path, options: options)
        return path
    }
}
