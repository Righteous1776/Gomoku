import Foundation

/// Research-only adapter around byte-identical VeilLink native unified search.
/// Deliberately NOT the production GomokuBot: its mandatory win/block gate,
/// learning repertoire and full seven-tier controller are not migrated yet.
/// Never promote this search to the player-facing default based on a smoke test.
enum NativeEclipseResearch {
    static func decide(
        cells: [UInt8],
        toMove: UInt8,
        difficulty: String = "balanced",
        maximumMilliseconds: Int = 350
    ) -> VeilGomokuUnifiedSearch.Decision? {
        guard let position = VeilGomokuUnifiedSearch.Position(
            cells: cells, toMove: toMove
        ) else { return nil }
        let budget = EclipseDifficultyPolicy.limits(
            rawValue: difficulty,
            maximumMilliseconds: max(30, maximumMilliseconds)
        )
        return VeilGomokuUnifiedSearch.decide(position, limits: budget)
    }
}
