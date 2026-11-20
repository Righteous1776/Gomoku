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
    @Published private(set) var trainingAttempted = 0
    @Published private(set) var trainingRejected = 0
    @Published var selfPlayLearningEnabled = UserDefaults.standard.object(forKey: "gomoku.eclipse.selfplay-feedback") as? Bool ?? true {
        didSet { UserDefaults.standard.set(selfPlayLearningEnabled, forKey: "gomoku.eclipse.selfplay-feedback") }
    }

    @Published var eclipseVisualizationEnabled = UserDefaults.standard.bool(forKey: "gomoku.eclipse.live-trace") {
        didSet {
            UserDefaults.standard.set(eclipseVisualizationEnabled, forKey: "gomoku.eclipse.live-trace")
            if !eclipseVisualizationEnabled { eclipseTraceStore.clear() }
        }
    }

    private(set) var state = GomokuState()
    let eclipseTraceStore = VeilEclipseSearchTraceStore()
    private var generation = UUID()
    private var searchTask: Task<Void, Never>?
    private let archive = VeilGomokuMatchArchive()
    private let trainingJournal = GomokuNativeTrainingJournal()
    private lazy var transfer = GomokuMatchTransfer(archive: archive)
    private(set) var sessionID = UUID().uuidString
    private var sessionHumanStone: UInt8 = 1
    private var archivedMoves: [VeilGomokuMatchArchive.Move] = []
    private var trainingTask: Task<Void, Never>?
    private var trainingGeneration = UUID()

    init() {
        trainedGames = trainingJournal.count()
        archivedGames = (try? archive.page(limit: 1).totalFiles) ?? 0
    }

    var humanColor: Int32 { humanIsBlack ? 1 : 2 }

    var completedMoves: [VeilEclipseTracePolicy.PlacedMove] {
        guard status != 0 else { return [] }
        return archivedMoves.map { .init(index: $0.index, stone: $0.stone) }
    }

    func historyPage(offset: Int, limit: Int) -> VeilGomokuMatchArchive.Page? {
        try? archive.page(offset: offset, limit: limit)
    }

    func reset() {
        if status == 0, !archivedMoves.isEmpty {
            persistArchive(status: .interrupted)
        }
        generation = UUID()
        searchTask?.cancel()
        searchTask = nil
        eclipseTraceStore.clear()
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
        let traceStore = eclipseTraceStore
        let observer: (@Sendable ([Int], Int) -> Void)?
        if eclipseVisualizationEnabled, let traceToken = traceStore.begin(sessionID: sessionID, board: boardAtStart) {
            observer = { indices, nodes in
                _ = traceStore.record(indices, nodes: nodes, token: traceToken)
            }
        } else {
            observer = nil
        }
        let journalDirectory = trainingJournal.directory
        let archiveDirectory = archive.directory
        let existingMoves = archivedMoves
        let humanStone = sessionHumanStone
        let useNativeTraining = selfPlayLearningEnabled
        searchTask = Task.detached(priority: .userInitiated) { [weak self] in
            guard !Task.isCancelled else { return }
            // Construct from verified records off the main/UI actor. The exact
            // immutable snapshot is used for this decision, not display only.
            let learning = GomokuLearningRepertoire.build(
                journalDirectory: journalDirectory,
                archiveDirectory: archiveDirectory,
                currentMoves: existingMoves,
                humanStone: humanStone,
                includeNativeSelfPlay: useNativeTraining
            ).snapshot
            guard !Task.isCancelled else { return }
            let budget = GomokuBotBudget.forDifficulty(
                selectedTier, profileLabel: selectedMode.budgetProfileLabel
            ).reinforced(by: learning.trainingLevel)
            let decision = GomokuBot.chooseMove(
                in: boardAtStart,
                for: boardAtStart.currentPlayer,
                budget: budget,
                learning: learning,
                formationPreference: .disabled,
                difficultyRawValue: selectedTier.rawValue,
                onExploredLine: observer
            )
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self, token == self.generation,
                      self.state == boardAtStart else { return }
                self.eclipseTraceStore.clear()
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

    func beginNativeSelfPlay(games: Int = 10) {
        guard !isNativeTraining, [1, 10, 100, 1000].contains(games) else { return }
        trainingGeneration = UUID()
        let token = trainingGeneration
        isNativeTraining = true
        trainingWarning = nil
        trainingAttempted = 0
        trainingRejected = 0
        let starting = trainedGames
        trainingTask = Task.detached(priority: .utility) { [weak self] in
            for batch in 0..<games {
                guard !Task.isCancelled,
                      await self?.isCurrentTrainingSession(token) == true else { break }
                let seed = starting + batch
                let result = NativeGomokuSelfPlay.play(seed: seed, formationMode: .off)
                guard !Task.isCancelled else { break }
                await self?.commitNativeTrainingResult(result, seed: seed, token: token)
            }
            await self?.finishNativeTrainingSession(token)
        }
    }

    private func isCurrentTrainingSession(_ token: UUID) -> Bool {
        isNativeTraining && trainingGeneration == token
    }

    private func commitNativeTrainingResult(
        _ game: NativeGomokuSelfPlayGame?, seed: Int, token: UUID
    ) {
        // Serialized with stop/start on MainActor: a stale task cannot write
        // a result after the Owner cancels or replaces the training session.
        guard isCurrentTrainingSession(token) else { return }
        trainingAttempted += 1
        guard let game else {
            trainingRejected += 1
            return
        }
        do {
            _ = try trainingJournal.append(game, seed: seed)
            trainedGames = trainingJournal.count()
        } catch {
            trainingRejected += 1
            trainingWarning = error.localizedDescription
        }
    }

    private func finishNativeTrainingSession(_ token: UUID) {
        guard isCurrentTrainingSession(token) else { return }
        isNativeTraining = false
        trainingTask = nil
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
        trainingGeneration = UUID()
        trainingTask?.cancel()
        trainingTask = nil
        isNativeTraining = false
    }
}
