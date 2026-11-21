import Foundation
import Combine

/// Temporary standalone integration with the C++ PROTOTYPE.
/// Production must NOT replace the original Swift ECLIPSE until parity gates pass.
@MainActor
final class EngineBridge: ObservableObject {
    @Published private(set) var board = [UInt8](repeating: 0, count: 225)
    @Published private(set) var toMove: Int32 = 1
    @Published private(set) var status: Int32 = 0
    @Published private(set) var isThinking = false
    @Published private(set) var searchStartedAt: Date?
    @Published var humanIsBlack = true

    private var handle: OpaquePointer?
    private var moves: [Int32] = []
    private var generation = UUID()

    init() {
        handle = eg_create()
        reload()
    }

    deinit {
        if let handle { eg_destroy(handle) }
    }

    var humanColor: Int32 { humanIsBlack ? 1 : 2 }

    func reset() {
        generation = UUID()
        isThinking = false
        searchStartedAt = nil
        moves.removeAll()
        if let handle { eg_reset(handle) }
        reload()
        if !humanIsBlack { scheduleAI() }
    }

    func toggleSide() {
        humanIsBlack.toggle()
        reset()
    }

    func play(_ index: Int) {
        guard !isThinking, status == 0, toMove == humanColor,
              let handle, (0..<225).contains(index) else { return }
        guard eg_play(handle, Int32(index)) == 1 else { return }
        moves.append(Int32(index))
        reload()
        if status == 0 { scheduleAI() }
    }

    private func reload() {
        guard let handle else { return }
        var snapshot = [UInt8](repeating: 0, count: 225)
        let result = snapshot.withUnsafeMutableBufferPointer { buffer in
            eg_copy_board(handle, buffer.baseAddress, Int32(buffer.count))
        }
        if result == 225 { board = snapshot }
        toMove = eg_to_move(handle)
        status = eg_status(handle)
    }

    private func scheduleAI() {
        guard !isThinking, status == 0, toMove != humanColor else { return }
        let token = generation
        let history = moves
        isThinking = true
        searchStartedAt = Date()
        Task.detached(priority: .userInitiated) {
            let worker = eg_create()
            var answer: Int32 = -1
            if let worker {
                let replayed = history.allSatisfy { eg_play(worker, $0) == 1 }
                if replayed { answer = eg_best_move(worker, 180) }
                eg_destroy(worker)
            }
            let selectedMove = answer
            await MainActor.run {
                guard token == self.generation else { return }
                self.isThinking = false
                self.searchStartedAt = nil
                guard let handle = self.handle, selectedMove >= 0,
                      eg_play(handle, selectedMove) == 1 else { return }
                self.moves.append(selectedMove)
                self.reload()
            }
        }
    }
}
