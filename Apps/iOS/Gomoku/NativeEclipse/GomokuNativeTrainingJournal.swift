import Foundation
import CryptoKit

/// Only real, fully replay-validated native self-play games are stored.
struct GomokuNativeTrainingRecord: Codable, Sendable {
    static let version = 1
    let version: Int
    let id: UUID
    let createdAt: Date
    let seed: Int
    let moves: [Int]
    /// Color provenance for imported owner games; nil for native/self-play seed records.
    /// Black/white outcomes remain encoded in `outcome` for backward compatibility.
    let outcome: AdaptiveBoardGameResult
    let humanStone: UInt8?

    init(version: Int, id: UUID, createdAt: Date, seed: Int,
         moves: [Int], outcome: AdaptiveBoardGameResult,
         humanStone: UInt8? = nil) {
        self.version = version
        self.id = id
        self.createdAt = createdAt
        self.seed = seed
        self.moves = moves
        self.outcome = outcome
        self.humanStone = humanStone
    }
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
    // Duplicate detection previously retained EVERY full 5..225-ply array
    // in RAM, once in inspect and again in BatchWriter. A fixed 32-byte
    // SHA256 fingerprint preserves the duplicate contract at a tiny fraction
    // of its former footprint. Hashes are ephemeral and never written.
    private static func fingerprint(_ moves: [Int]) -> Data {
        let bytes = moves.withUnsafeBufferPointer { Data(buffer: $0) }
        return Data(SHA256.hash(data: bytes))
    }

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

    struct VerificationReport: Equatable, Sendable {
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
        var sequences = Set<Data>()
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
            guard sequences.insert(Self.fingerprint(record.moves)).inserted else {
                duplicates += 1
                continue
            }
            accepted += 1
            receive?(record)
        }
        return VerificationReport(accepted: accepted, invalid: invalid, duplicates: duplicates)
    }

    func count() -> Int { inspect().accepted }

    enum ExportError: LocalizedError {
        case noSavedGames

        var errorDescription: String? {
            "尚无完整、已验证的原生自对弈棋局，未生成空白导出。"
        }
    }

    /// Original VeilLink exposed a per-ply self-play export independently from
    /// ordinary player match/learning packages. Export *only* replay-validated
    /// native evidence in an explicit, standalone JSON schema. Stream records
    /// directly to disk rather than accumulating potentially unlimited games
    /// in an in-memory JSON array. This is not the legacy .vltrain import format.
    func exportVerifiedDetails() throws -> URL {
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("GomokuNativeSelfPlay-" + UUID().uuidString + ".json")
        var protection: Data.WritingOptions = [.atomic]
        #if canImport(UIKit)
        protection.insert(.completeFileProtectionUntilFirstUserAuthentication)
        #endif
        try Data().write(to: destination, options: protection)
        let handle: FileHandle
        do {
            handle = try FileHandle(forWritingTo: destination)
        } catch {
            try? FileManager.default.removeItem(at: destination)
            throw error
        }

        do {
            try handle.write(contentsOf: Data(
                #"{"schema":"gomoku.native.selfplay-details.v1","games":["#.utf8
            ))
            let encoder = JSONEncoder()
            var wroteGame = false
            var writeError: Error?
            let report = inspect { record in
                guard writeError == nil else { return }
                do {
                    if wroteGame {
                        try handle.write(contentsOf: Data(",".utf8))
                    }
                    try handle.write(contentsOf: encoder.encode(record))
                    wroteGame = true
                } catch {
                    writeError = error
                }
            }
            if let writeError { throw writeError }
            guard report.invalid == 0 && report.duplicates == 0 else {
                throw GomokuNativeTrainingJournalError.corrupted
            }
            guard report.accepted > 0 else { throw ExportError.noSavedGames }
            try handle.write(contentsOf: Data(
                "],\"verifiedGames\":\(report.accepted)}".utf8
            ))
            try handle.close()
            return destination
        } catch {
            try? handle.close()
            try? FileManager.default.removeItem(at: destination)
            throw error
        }
    }


    static func isValid(_ record: GomokuNativeTrainingRecord) -> Bool {
        guard record.version == GomokuNativeTrainingRecord.version,
              (5...225).contains(record.moves.count),
              record.outcome != .unfinished,
              record.humanStone == nil || record.humanStone == 1 || record.humanStone == 2
              else { return false }
        var replay = GomokuState()
        for index in record.moves {
            guard replay.apply(index: index, actor: replay.currentPlayer) else { return false }
        }
        let outcome: AdaptiveBoardGameResult = replay.isDraw ? .draw
            : replay.winner == .guest ? .aiWon
            : replay.winner == .host ? .humanWon : .unfinished
        return outcome == record.outcome
    }

    /// One expensive full content inspection per batch, then O(1)-average
    /// in-memory sequence deduplication for new games. The batch is bound to
    /// one serial writer and should be created off the UI actor. An externally
    /// changed or damaged archive requires a new audit before another batch.
    final class BatchWriter {
        private let journal: GomokuNativeTrainingJournal
        private var seen: Set<Data> = []
        private(set) var accepted: Int = 0
        let initialValidCount: Int

        init(journal: GomokuNativeTrainingJournal) throws {
            self.journal = journal
            var inspectedSequences = Set<Data>()
            let report = journal.inspect { record in
                inspectedSequences.insert(GomokuNativeTrainingJournal.fingerprint(record.moves))
            }
            guard report.invalid == 0, report.duplicates == 0 else {
                throw GomokuNativeTrainingJournalError.corrupted
            }
            seen = inspectedSequences
            initialValidCount = report.accepted
        }

        @discardableResult
        func append(_ game: NativeGomokuSelfPlayGame, seed: Int,
                    humanStone: UInt8? = nil) throws -> URL {
            let moves = try GomokuNativeTrainingJournal.verifiedMoves(game)
            let digest = GomokuNativeTrainingJournal.fingerprint(moves)
            guard !seen.contains(digest) else {
                throw GomokuNativeTrainingJournalError.duplicate
            }
            let path = try journal.writeVerified(
                moves: moves, result: game.result, seed: seed, humanStone: humanStone
            )
            seen.insert(digest)
            accepted += 1
            return path
        }

        var totalValidCount: Int { initialValidCount + accepted }
    }

    func makeBatchWriter() throws -> BatchWriter {
        try BatchWriter(journal: self)
    }

    /// Every datum, including winner attribution, is checked before the
    /// separate durable write. No outcome inferred from an untrusted label.
    private static func verifiedMoves(_ game: NativeGomokuSelfPlayGame) throws -> [Int] {
        guard game.completed, !game.plies.isEmpty, game.plies.count <= 225 else {
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
        return indices
    }

    private func writeVerified(
        moves: [Int], result: AdaptiveBoardGameResult, seed: Int,
        humanStone: UInt8? = nil
    ) throws -> URL {
        let id = UUID()
        let record = GomokuNativeTrainingRecord(
            version: GomokuNativeTrainingRecord.version, id: id,
            createdAt: Date(), seed: seed, moves: moves, outcome: result,
            humanStone: humanStone
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

    @discardableResult
    func append(_ game: NativeGomokuSelfPlayGame, seed: Int) throws -> URL {
        let indices = try Self.verifiedMoves(game)
        var found = false
        inspect { record in
            if record.moves == indices { found = true }
        }
        guard !found else { throw GomokuNativeTrainingJournalError.duplicate }
        return try writeVerified(moves: indices, result: game.result, seed: seed)
    }
}
