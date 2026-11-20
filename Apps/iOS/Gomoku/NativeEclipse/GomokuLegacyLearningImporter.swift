import Foundation
import CryptoKit

/// Imports explicitly user-selected VeilLink .vltrain.json packages. The only
/// promoted evidence is fully replayable Gomoku terminal move history. Legacy
/// positional aggregates cannot prove their own source moves and are NOT
/// trusted merely because the envelope checksum matches.
final class GomokuLegacyLearningImporter {
    private struct ActionStat: Codable {
        let count: Int
        let aiReward: Int
    }
    private struct PositionStat: Codable {
        let actor: MiniGamePlayer
        let actions: [String: ActionStat]
        let lastSequence: Int
    }
    private struct GameRecord: Codable {
        let game: String
        let result: AdaptiveBoardGameResult
        let actions: [String]
        let finishedAt: Date
    }
    private struct LegacyDatabase: Codable {
        let schema: Int
        let completedGames: Int
        let sequence: Int
        let positions: [String: PositionStat]
        let recentGames: [GameRecord]
    }
    private struct Envelope: Codable {
        let format: String
        let createdAt: Date
        let appVersion: String
        let checksumAlgorithm: String
        let payloadChecksum: String
        let payload: LegacyDatabase
    }

    enum ImportError: LocalizedError {
        case unsupported, checksum, invalidHistory, damagedDestination, oversized, unauthorized
        var errorDescription: String? {
            switch self {
            case .unauthorized: return "开发者身份验证已过期，尚未修改现有训练库。"
            case .unsupported: return "训练包不是 VeilLink v1 的有效五子棋学习导出。"
            case .checksum: return "训练包校验和不匹配，原有学习数据未更改。"
            case .invalidHistory: return "原始走子或胜负标签无法复验，拒绝导入。"
            case .damagedDestination: return "现有学习档案已损坏，已保护原件，请先只读恢复。"
            case .oversized: return "单个训练包超出本次安全导入的 64 MiB；可分批导出。"
            }
        }
    }

    struct ImportReport {
        let imported: Int
        let duplicate: Int
        let ignoredNonGomoku: Int
        let totalUnique: Int
        let backup: URL?
        /// Original file is retained, including unfinished games and hash-only positions.
        let preservedPartialGames: Int
        let preservedHashedPositions: Int
        let sourceSHA256: String
    }

    let directory: URL
    init(directory: URL? = nil) {
        if let directory { self.directory = directory }
        else {
            let root = FileManager.default.urls(
                for: .applicationSupportDirectory, in: .userDomainMask
            ).first ?? FileManager.default.temporaryDirectory
            self.directory = root.appendingPathComponent("Gomoku", isDirectory: true)
                .appendingPathComponent("ImportedLegacyLearningV1", isDirectory: true)
        }
    }

    @discardableResult
    func importPackage(from selectedURL: URL, authorization: GomokuDeveloperPermit.Authorization? = nil) throws -> ImportReport {
        guard let authorization, authorization.isValid else { throw ImportError.unauthorized }
        let scoped = selectedURL.startAccessingSecurityScopedResource()
        defer { if scoped { selectedURL.stopAccessingSecurityScopedResource() } }
        guard selectedURL.lastPathComponent.lowercased().hasSuffix(".vltrain.json") else {
            throw ImportError.unsupported
        }
        let resource = try selectedURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard resource.isRegularFile == true, let size = resource.fileSize, size > 0 else {
            throw ImportError.unsupported
        }
        guard size <= 64 * 1_024 * 1_024 else { throw ImportError.oversized }
        let bytes = try Data(contentsOf: selectedURL, options: .mappedIfSafe)
        guard bytes.count == size,
              let envelope = try? JSONDecoder().decode(Envelope.self, from: bytes),
              envelope.format == "veillink.board-learning.export.v1",
              envelope.checksumAlgorithm == "fnv1a64-canonical-json",
              envelope.payload.schema == 1,
              envelope.payload.completedGames >= 0,
              envelope.payload.sequence >= 0 else { throw ImportError.unsupported }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let canonical = try? encoder.encode(envelope.payload),
              Self.fnv(canonical) == envelope.payloadChecksum else { throw ImportError.checksum }

        // Validate original bounds, but never promote x: or unprovable g:
        // aggregate scores. Only original fully replayed matches become knowledge.
        for (position, stat) in envelope.payload.positions {
            guard position.count <= 96, position.hasPrefix("g:") || position.hasPrefix("x:"),
                  stat.lastSequence >= 0 else { throw ImportError.invalidHistory }
            for (action, counter) in stat.actions {
                guard (1...65_535).contains(counter.count),
                      (-32_000...32_000).contains(counter.aiReward) else {
                    throw ImportError.invalidHistory
                }
                if position.hasPrefix("g:") {
                    guard let move = Int(action), (0..<225).contains(move) else {
                        throw ImportError.invalidHistory
                    }
                }
            }
        }
        let manager = FileManager.default
        let parent = directory.deletingLastPathComponent()
        let stage = parent.appendingPathComponent(
            "ImportedLegacyLearningV1.stage-" + UUID().uuidString, isDirectory: true
        )
        try manager.createDirectory(at: stage, withIntermediateDirectories: true)
        var needsCleanup = true
        defer { if needsCleanup { try? manager.removeItem(at: stage) } }

        let existing = GomokuNativeTrainingJournal(directory: directory)
        let oldReport = existing.inspect()
        guard oldReport.invalid == 0, oldReport.duplicates == 0 else {
            throw ImportError.damagedDestination
        }
        if manager.fileExists(atPath: directory.path) {
            for file in try manager.contentsOfDirectory(
                at: directory, includingPropertiesForKeys: [.isRegularFileKey]
            ) where file.pathExtension == "json" {
                try manager.copyItem(at: file, to: stage.appendingPathComponent(file.lastPathComponent))
            }
        }
        // Preserve every previously imported original source inside the same
        // transactional directory. Do not discard partial games or aggregates
        // merely because they are not promotable model training examples.
        let rawSources = stage.appendingPathComponent("RawSources", isDirectory: true)
        let previousSources = directory.appendingPathComponent("RawSources", isDirectory: true)
        if manager.fileExists(atPath: previousSources.path) {
            try manager.copyItem(at: previousSources, to: rawSources)
        } else {
            try manager.createDirectory(at: rawSources, withIntermediateDirectories: true)
        }
        let sourceSHA256 = SHA256.hash(data: bytes).map {
            String(format: "%02x", $0)
        }.joined()
        let retainedSource = rawSources.appendingPathComponent(sourceSHA256 + ".vltrain.json")
        var writeOptions: Data.WritingOptions = [.atomic]
        #if canImport(UIKit)
        writeOptions.insert(.completeFileProtectionUntilFirstUserAuthentication)
        #endif
        try bytes.write(to: retainedSource, options: writeOptions)

        let staged = GomokuNativeTrainingJournal(directory: stage)
        let batchWriter = try staged.makeBatchWriter()
        var imported = 0, duplicated = 0, ignored = 0, partial = 0
        for (ordinal, record) in envelope.payload.recentGames.enumerated() {
            guard record.game == "gomoku" else {
                guard record.game == "xiangqi" else { throw ImportError.invalidHistory }
                ignored += 1
                continue
            }
            // Even the unfinished records must replay legally before the raw
            // export is admitted to the protected on-device archive.
            guard record.actions.count <= 225,
                  record.actions.count >= (record.result == .unfinished ? 0 : 5) else {
                throw ImportError.invalidHistory
            }
            var state = GomokuState()
            var plies: [AdaptiveBoardPly] = []
            plies.reserveCapacity(record.actions.count)
            for action in record.actions {
                guard let prefix = action.first, prefix == "h" || prefix == "a",
                      let index = Int(action.dropFirst()), (0..<225).contains(index) else {
                    throw ImportError.invalidHistory
                }
                let actor: MiniGamePlayer = prefix == "h" ? .host : .guest
                let ply = AdaptiveBoardPly(
                    position: AdaptiveBoardPosition.gomoku(state),
                    action: String(index), actor: actor
                )
                guard actor == state.currentPlayer, state.apply(index: index, actor: actor) else {
                    throw ImportError.invalidHistory
                }
                plies.append(ply)
            }
            let verified: AdaptiveBoardGameResult = state.isDraw ? .draw
                : state.winner == .guest ? .aiWon
                : state.winner == .host ? .humanWon : .unfinished
            guard verified == record.result else { throw ImportError.invalidHistory }
            if verified == .unfinished {
                partial += 1
                continue
            }
            let game = NativeGomokuSelfPlayGame(
                plies: plies, result: verified,
                opening: Int(plies[0].action) ?? 112,
                botDecisions: max(0, plies.count - 1)
            )
            do {
                try batchWriter.append(game, seed: ordinal)
                imported += 1
            } catch GomokuNativeTrainingJournalError.duplicate {
                duplicated += 1
            }
        }
        guard imported > 0 || oldReport.accepted > 0,
              staged.inspect().invalid == 0 else { throw ImportError.invalidHistory }
        // Recheck the staging repository before replacing the live dataset.
        let validated = staged.inspect()
        guard validated.accepted == oldReport.accepted + imported else {
            throw ImportError.invalidHistory
        }
        // The privileged directory swap is atomic with permit validation:
        // revoking the developer session prevents a stale detached importer
        // from modifying the training knowledge base.
        guard let committed = try authorization.commit({
            let backup: URL? = manager.fileExists(atPath: directory.path)
                ? parent.appendingPathComponent("ImportedLegacyLearningV1.backup-" + UUID().uuidString)
                : nil
            if let backup { try manager.moveItem(at: directory, to: backup) }
            do {
                try manager.moveItem(at: stage, to: directory)
                needsCleanup = false
            } catch {
                if let backup { try? manager.moveItem(at: backup, to: directory) }
                throw error
            }
            return ImportReport(
                imported: imported, duplicate: duplicated,
                ignoredNonGomoku: ignored, totalUnique: validated.accepted,
                backup: backup, preservedPartialGames: partial,
                preservedHashedPositions: envelope.payload.positions.filter {
                    $0.key.hasPrefix("g:")
                }.count, sourceSHA256: sourceSHA256
            )
        }) else {
            throw ImportError.unauthorized
        }
        return committed
    }

    private static func fnv(_ data: Data) -> String {
        var value: UInt64 = 14_695_981_039_346_656_037
        for byte in data {
            value ^= UInt64(byte)
            value &*= 1_099_511_628_211
        }
        return String(value, radix: 16)
    }
}
