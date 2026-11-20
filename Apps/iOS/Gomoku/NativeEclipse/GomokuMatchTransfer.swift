import Foundation

/// Explicit user-selected match JSON import/export. Never reads another app's
/// sandbox, private chat records or any unverified training archive.
enum GomokuMatchTransferError: LocalizedError {
    case invalidFile, tooLarge, unsupported, duplicate, empty
    var errorDescription: String? {
        switch self {
        case .invalidFile: return "棋谱格式或落子合法性校验失败；未修改现有记录。"
        case .tooLarge: return "单局棋谱过大，已拒绝读取；可以分批导入独立棋局。"
        case .unsupported: return "只允许原版 ECLIPSE 五子棋逐局 JSON 文件。"
        case .duplicate: return "此局已经存在；原记录不会被覆盖。"
        case .empty: return "暂无已保存的棋谱可导出。"
        }
    }
}

final class GomokuMatchTransfer {
    private let archive: VeilGomokuMatchArchive
    init(archive: VeilGomokuMatchArchive = VeilGomokuMatchArchive()) {
        self.archive = archive
    }

    /// Returns a temporary file suitable for a user-controlled system share sheet.
    func exportMostRecent() throws -> URL {
        guard let match = try archive.page(limit: 1).matches.first else {
            throw GomokuMatchTransferError.empty
        }
        let data = try JSONEncoder().encode(match)
        guard data.count <= 128_000 else { throw GomokuMatchTransferError.tooLarge }
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("Gomoku-" + match.id + ".json")
        try data.write(to: path, options: .atomic)
        return path
    }

    /// Accepts a user-chosen JSON file; never silently overwrites even an
    /// identical session. Validation and durable save use original archive code.
    @discardableResult
    func importMatch(from userURL: URL) throws -> String {
        let access = userURL.startAccessingSecurityScopedResource()
        defer { if access { userURL.stopAccessingSecurityScopedResource() } }

        guard userURL.pathExtension.lowercased() == "json" else {
            throw GomokuMatchTransferError.unsupported
        }
        let metadata = try userURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
        guard metadata.isRegularFile == true else { throw GomokuMatchTransferError.invalidFile }
        guard let byteCount = metadata.fileSize, (1...128_000).contains(byteCount) else {
            throw GomokuMatchTransferError.tooLarge
        }
        let data = try Data(contentsOf: userURL, options: .mappedIfSafe)
        guard data.count == byteCount,
              let record = try? JSONDecoder().decode(
                VeilGomokuMatchArchive.Match.self, from: data),
              record.version == VeilGomokuMatchArchive.Match.version,
              UUID(uuidString: record.id)?.uuidString == record.id,
              !record.moves.isEmpty, record.moves.count <= 225,
              (1...2).contains(record.humanStone),
              record.isReplayable,
              record.completedAt == nil || record.status.isFinal,
              record.updatedAt >= record.startedAt else {
            throw GomokuMatchTransferError.invalidFile
        }
        guard try archive.read(sessionID: record.id) == nil else {
            throw GomokuMatchTransferError.duplicate
        }
        // Original archive.save validates win/draw consistency, turn order,
        // move bounds, id, conflict safety and writes atomically.
        guard let saved = try archive.save(
            sessionID: record.id, moves: record.moves,
            difficulty: record.difficulty, humanStone: record.humanStone,
            status: record.status, now: record.updatedAt
        ) else {
            throw GomokuMatchTransferError.invalidFile
        }
        return saved.id
    }
}
