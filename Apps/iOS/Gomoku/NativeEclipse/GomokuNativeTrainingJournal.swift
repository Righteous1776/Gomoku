import Foundation

/// Only real, fully replay-validated native self-play games are stored.
struct GomokuNativeTrainingRecord: Codable, Sendable {
    static let version = 1
    let version: Int
    let id: UUID
    let createdAt: Date
    let seed: Int
    let moves: [Int]
    let outcome: AdaptiveBoardGameResult
}

enum GomokuNativeTrainingJournalError: LocalizedError {
    case invalidGame, corrupted, duplicate
    var errorDescription: String? {
        switch self {
        case .invalidGame: return "本局训练未完成或棋谱复验失败，未计入训练次数。"
        case .corrupted: return "训练档案校验失败，原文件已保留。"
        case .duplicate: return "重复棋谱已存在，未增加有效训练经验。"
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

    struct VerificationReport: Equatable {
        let accepted: Int
        let invalid: Int
        let duplicates: Int
    }

    /// Checks the content, terminal outcome and unique *move sequence* of each
    /// retained file. Invalid files remain untouched for manual recovery.
    /// FileManager's directory enumerator avoids loading the archive at once.
    @discardableResult
    func inspect(_ receive: ((GomokuNativeTrainingRecord) -> Void)? = nil) -> VerificationReport {
        guard FileManager.default.fileExists(atPath: directory.path),
              let files = FileManager.default.enumerator(
                at: directory, includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
                options: [.skipsHiddenFiles]
              ) else {
            return VerificationReport(accepted: 0, invalid: 0, duplicates: 0)
        }
        var accepted = 0, invalid = 0, duplicates = 0
        var sequences = Set<[Int]>()
        for case let file as URL in files {
            guard file.deletingLastPathComponent().standardizedFileURL == directory.standardizedFileURL,
                  file.pathExtension == "json",
                  UUID(uuidString: file.deletingPathExtension().lastPathComponent) != nil else { continue }
            guard let metadata = try? file.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                  metadata.isRegularFile == true,
                  let size = metadata.fileSize, (1...128_000).contains(size),
                  let bytes = try? Data(contentsOf: file),
                  let record = try? JSONDecoder().decode(GomokuNativeTrainingRecord.self, from: bytes),
                  record.id.uuidString == file.deletingPathExtension().lastPathComponent,
                  Self.isValid(record) else {
                invalid += 1
                continue
            }
            guard sequences.insert(record.moves).inserted else {
                duplicates += 1
                continue
            }
            accepted += 1
            receive?(record)
        }
        return VerificationReport(accepted: accepted, invalid: invalid, duplicates: duplicates)
    }

    func count() -> Int { inspect().accepted }

    static func isValid(_ record: GomokuNativeTrainingRecord) -> Bool {
        guard record.version == GomokuNativeTrainingRecord.version,
              (5...225).contains(record.moves.count),
              record.outcome != .unfinished else { return false }
        var replay = GomokuState()
        for index in record.moves {
            guard replay.apply(index: index, actor: replay.currentPlayer) else { return false }
        }
        let outcome: AdaptiveBoardGameResult = replay.isDraw ? .draw
            : replay.winner == .guest ? .aiWon
            : replay.winner == .host ? .humanWon : .unfinished
        return outcome == record.outcome
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
        let verifiedOutcome: AdaptiveBoardGameResult = replay.isDraw ? .draw
            : replay.winner == .guest ? .aiWon
            : replay.winner == .host ? .humanWon : .unfinished
        guard verifiedOutcome != .unfinished, verifiedOutcome == game.result else {
            throw GomokuNativeTrainingJournalError.invalidGame
        }
        var alreadyRecorded = false
        inspect { record in
            if record.moves == indices { alreadyRecorded = true }
        }
        guard !alreadyRecorded else { throw GomokuNativeTrainingJournalError.duplicate }
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
