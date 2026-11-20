import Foundation
import Combine

/// Standalone Swift ECLIPSE driver. Uses the original VeilLink GomokuBot,
/// its exact tactical gates, native unified search and seven-level budgets.
/// Does not silently replace research C++ files or claim historical training
/// data migrated. No network, Xiangqi or VeilLink messaging dependencies.
@MainActor
final class NativeGomokuAppController: ObservableObject {
    @Published private(set) var board = [UInt8](repeating: 0, count: 225)
    @Published private(set) var toMove: Int32 = 1
    @Published private(set) var status: Int32 = 0
    @Published private(set) var isThinking = false
    @Published private(set) var searchStartedAt: Date?
    @Published private(set) var lastDecisionNodes: Int?
    @Published private(set) var lastDecisionMilliseconds: Int?
    @Published private(set) var fallbackWarning: String?
    @Published var humanIsBlack = true
    @Published var difficulty: BoardBotDifficulty = .balanced
    @Published var searchMode: BoardSearchMode = .full
    @Published private(set) var archivedGames = 0
    @Published private(set) var archiveWarning: String?
    @Published private(set) var trainedGames = 0
    @Published private(set) var isNativeTraining = false
    @Published private(set) var trainingWarning: String?

    private var state = GomokuState()
    private var generation = UUID()
    private var searchTask: Task<Void, Never>?
    private let archive = VeilGomokuMatchArchive()
    private let trainingJournal = GomokuNativeTrainingJournal()
    private lazy var transfer = GomokuMatchTransfer(archive: archive)
    private var sessionID = UUID().uuidString
    private var sessionHumanStone: UInt8 = 1
    private var archivedMoves: [VeilGomokuMatchArchive.Move] = []
    private var trainingTask: Task<Void, Never>?

    init() {
        trainedGames = trainingJournal.count()
        archivedGames = (try? archive.page(limit: 1).totalFiles) ?? 0
    }

    var humanColor: Int32 { humanIsBlack ? 1 : 2 }

    func reset() {
        if status == 0, !archivedMoves.isEmpty {
            persistArchive(status: .interrupted)
        }
        generation = UUID()
        searchTask?.cancel()
        searchTask = nil
        state = GomokuState()
        sessionID = UUID().uuidString
        sessionHumanStone = humanIsBlack ? 1 : 2
        archivedMoves.removeAll()
        isThinking = false
        searchStartedAt = nil
        lastDecisionNodes = nil
        lastDecisionMilliseconds = nil
        fallbackWarning = nil
        refresh()
        if !humanIsBlack { scheduleAI() }
    }

    func toggleSide() {
        humanIsBlack.toggle()
        reset()
    }

    func play(_ index: Int) {
        guard !isThinking, status == 0, Int32(state.currentPlayer == .host ? 1 : 2) == humanColor,
              state.apply(index: index, actor: state.currentPlayer) else { return }
        archivedMoves.append(.init(index: index, stone: UInt8(humanColor)))
        persistArchive(status: archiveStatus())
        refresh()
        if status == 0 { scheduleAI() }
    }

    private func refresh() {
        board = (0..<225).map { UInt8(max(0, state.value(at: $0))) }
        toMove = state.currentPlayer == .host ? 1 : 2
        if state.winner == .host { status = 1 }
        else if state.winner == .guest { status = 2 }
        else if state.isDraw { status = 3 }
        else { status = 0 }
    }

    private func scheduleAI() {
        guard !isThinking, status == 0 else { return }
        let token = generation
        let boardAtStart = state
        let selectedTier = difficulty
        let selectedMode = searchMode
        isThinking = true
        searchStartedAt = Date()
        fallbackWarning = nil
        searchTask = Task.detached(priority: .userInitiated) { [weak self] in
            guard !Task.isCancelled else { return }
            let budget = GomokuBotBudget.forDifficulty(
                selectedTier, profileLabel: selectedMode.budgetProfileLabel
            )
            let decision = GomokuBot.chooseMove(
                in: boardAtStart,
                for: boardAtStart.currentPlayer,
                budget: budget,
                learning: .empty,
                formationPreference: .disabled,
                difficultyRawValue: selectedTier.rawValue
            )
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self, token == self.generation,
                      self.state == boardAtStart else { return }
                self.isThinking = false
                self.searchStartedAt = nil
                self.searchTask = nil
                self.lastDecisionNodes = decision?.nodes
                self.lastDecisionMilliseconds = decision?.elapsedMilliseconds
                let selectedIndex: Int
                if let decision, boardAtStart.value(at: decision.index) == 0 {
                    selectedIndex = decision.index
                } else if let legal = (0..<225).first(where: { boardAtStart.value(at: $0) == 0 }) {
                    selectedIndex = legal
                    self.fallbackWarning = "搜索未返回有效落子，已采用合法性保底；本局不计入棋力评测。"
                } else {
                    self.refresh()
                    return
                }
                guard self.state.apply(index: selectedIndex, actor: self.state.currentPlayer) else {
                    self.fallbackWarning = "搜索结果未能落子，请重开棋局。"
                    return
                }
                self.archivedMoves.append(.init(index: selectedIndex, stone: UInt8(boardAtStart.currentPlayer == .host ? 1 : 2)))
                self.persistArchive(status: self.archiveStatus())
                self.refresh()
            }
        }
    }

    private func archiveStatus() -> VeilGomokuMatchArchive.Status {
        if status == 3 || state.isDraw { return .draw }
        if let winner = state.winner {
            let winnerStone: UInt8 = winner == .host ? 1 : 2
            return winnerStone == sessionHumanStone ? .humanWon : .aiWon
        }
        return .playing
    }

    private func persistArchive(status state: VeilGomokuMatchArchive.Status) {
        guard !archivedMoves.isEmpty else { return }
        do {
            _ = try archive.save(
                sessionID: sessionID, moves: archivedMoves,
                difficulty: difficulty.rawValue,
                humanStone: sessionHumanStone, status: state
            )
            archivedGames = (try? archive.page(limit: 1).totalFiles) ?? archivedGames
            archiveWarning = nil
        } catch {
            archiveWarning = error.localizedDescription
        }
    }

    func beginNativeSelfPlay(games: Int = 1) {
        guard !isNativeTraining, games > 0 else { return }
        isNativeTraining = true
        trainingWarning = nil
        let starting = trainedGames
        trainingTask = Task.detached(priority: .utility) { [weak self] in
            for batch in 0..<games {
                guard !Task.isCancelled else { break }
                let seed = starting + batch
                let result = NativeGomokuSelfPlay.play(seed: seed, formationMode: .off)
                if let result {
                    do {
                        let store = GomokuNativeTrainingJournal()
                        _ = try store.append(result, seed: seed)
                        await MainActor.run {
                            self?.trainedGames = store.count()
                        }
                    } catch {
                        let message = error.localizedDescription
                        await MainActor.run { self?.trainingWarning = message }
                    }
                }
            }
            await MainActor.run {
                self?.isNativeTraining = false
                self?.trainingTask = nil
            }
        }
    }

    func exportRecentMatch() -> URL? {
        do {
            archiveWarning = nil
            return try transfer.exportMostRecent()
        } catch {
            archiveWarning = error.localizedDescription
            return nil
        }
    }

    func importMatch(from url: URL) {
        do {
            _ = try transfer.importMatch(from: url)
            archivedGames = try archive.page(limit: 1).totalFiles
            archiveWarning = nil
        } catch {
            archiveWarning = error.localizedDescription
        }
    }

    func stopNativeSelfPlay() {
        trainingTask?.cancel()
        trainingTask = nil
        isNativeTraining = false
    }
}
