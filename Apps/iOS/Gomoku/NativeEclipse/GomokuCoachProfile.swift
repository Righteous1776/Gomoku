import Foundation

/// Personal coach generated only from replay-validated standalone Gomoku data.
struct GomokuCoachProfile: Sendable {
    let level: Int
    let completedHumanGames: Int
    let verifiedSelfPlayGames: Int
    let verifiedLegacyGames: Int
    let rememberedPositions: Int
    let favoriteOpening: String
    let repeatedLosingLines: Int
    let developerFormations: Int
    let nextLesson: String
    let reviewFocus: String

    static func build(
        archiveDirectory: URL,
        trainingDirectory: URL,
        developerFormationCount: Int
    ) -> GomokuCoachProfile {
        let archive = VeilGomokuMatchArchive(directory: archiveDirectory)
        var openings: [Int: Int] = [:]
        var lostPrefixes: [String: Int] = [:]
        var completed = 0
        var won = 0
        var lost = 0
        var offset = 0
        while let page = try? archive.page(offset: offset, limit: 50) {
            for match in page.matches {
                guard match.status == .humanWon || match.status == .aiWon
                        || match.status == .draw else { continue }
                completed += 1
                if match.status == .humanWon { won += 1 }
                if match.status == .aiWon { lost += 1 }
                if let first = match.moves.first(where: { $0.stone == match.humanStone }) {
                    openings[first.index, default: 0] += 1
                }
                if match.status == .aiWon {
                    let prefix = match.moves.prefix(6).map {
                        "\($0.stone):\($0.index)"
                    }.joined(separator: ",")
                    lostPrefixes[prefix, default: 0] += 1
                }
            }
            guard let next = page.nextOffset, next > offset else { break }
            offset = next
        }
        let repertoire = GomokuLearningRepertoire.build(
            journalDirectory: trainingDirectory,
            archiveDirectory: archiveDirectory,
            currentMoves: [], humanStone: 1
        )
        let remembered = repertoire.snapshot.preferences.count
        let level = min(10, max(1, 1 + completed / 3 + remembered / 180))
        let favorite: String
        if let opening = openings.max(by: {
            $0.value == $1.value ? $0.key > $1.key : $0.value < $1.value
        })?.key {
            let row = opening / 15, column = opening % 15
            favorite = abs(row - 7) <= 2 && abs(column - 7) <= 2
                ? "偏好中心开局（\(row + 1), \(column + 1)）"
                : "偏好边侧开局（\(row + 1), \(column + 1)）"
        } else {
            favorite = "暂无经过验证的完整个人对局"
        }
        let repeated = lostPrefixes.values.filter { $0 >= 2 }.count
        let review: String
        let lesson: String
        if completed == 0 {
            review = "先完成一局，才会生成基于真实棋谱的针对性反馈。"
            lesson = "先练习识别活三、冲四和对手的五连威胁。"
        } else if repeated > 0 {
            review = "已识别 \(repeated) 种重复失利的开局前缀，建议优先逐局复盘。"
            lesson = "复盘重复失败的前六手，练习不同应手与防守转换。"
        } else if lost > won {
            review = "近期归档中失败对局多于获胜对局，可优先检查防守。"
            lesson = "每步先识别对手的强制威胁，再考虑布局。"
        } else {
            review = "完整对局已纳入统计，继续观察不同开局的稳定性。"
            lesson = "尝试同一开局的两种应手，比较后续攻防。"
        }
        return GomokuCoachProfile(
            level: level,
            completedHumanGames: completed,
            verifiedSelfPlayGames: repertoire.validNativeGames,
            verifiedLegacyGames: repertoire.validLegacyGames,
            rememberedPositions: remembered,
            favoriteOpening: favorite,
            repeatedLosingLines: repeated,
            developerFormations: developerFormationCount,
            nextLesson: lesson, reviewFocus: review
        )
    }
}
