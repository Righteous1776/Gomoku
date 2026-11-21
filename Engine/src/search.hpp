#pragma once
#include "board.hpp"
#include <array>
#include <chrono>
#include <cstdint>
#include <unordered_map>
#include <vector>

namespace eclipse {
// Experimental search telemetry. NOT native Swift ECLIPSE strength parity.
// The enum's integer values are frozen by EG_SEARCH_DIAGNOSTICS_ABI_VERSION 1.
enum class SearchStopReason : int {
    complete = 0,
    forced_win = 1,
    forced_block = 2,
    only_move = 3,
    no_move = 4,
    time_limit = 5
};

struct SearchResult {
    int move = -1;
    std::uint64_t nodes = 0;
    int completed_depth = 0;
    int elapsed_ms = 0;
    SearchStopReason reason = SearchStopReason::no_move;
};

// V1 bounded root policy from the unchanged Swift learning/formation layer.
// Restrictions cannot bypass mandatory immediate win / block checks.
struct RootPolicy {
    std::array<bool, kCells> allowed{};
    std::array<int, kCells> bonus{};
};

class Search {
public:
    SearchResult analyze(const Board &root, int milliseconds,
                         const RootPolicy *policy = nullptr);
    int best_move(const Board &root, int milliseconds);

private:
    using Clock = std::chrono::steady_clock;
    static constexpr int kMate = 10'000'000;
    static constexpr int kInf = kMate + 100'000;
    struct Entry {
        int depth = 0;
        int score = 0;
        int best = -1;
        int flag = 0; // exact 0; lower 1; upper 2
    };
    std::array<std::uint8_t, kCells> cells_{};
    int free_ = kCells;
    std::uint64_t hash_ = 0;
    std::uint64_t nodes_ = 0;
    std::uint64_t node_cap_ = 80'000;
    bool timed_out_ = false;
    std::array<bool, kCells> allowed_proof_root_{};
    Clock::time_point deadline_{};
    Clock::time_point proof_deadline_{};
    std::unordered_map<std::uint64_t, Entry> table_;

    static constexpr int other(int side) { return side == 1 ? 2 : 1; }
    static bool inside(int row, int col) {
        return row >= 0 && row < kSide && col >= 0 && col < kSide;
    }
    static const std::array<std::array<std::uint64_t, 3>, kCells> &zobrist();
    static const std::array<std::uint64_t, 3> &side_hash();
    void place(int index, int side);
    void unplace(int index, int side);
    bool five_at(int index, int side) const;
    bool winning_move(int index, int side) const;
    std::vector<int> neighbors(int radius = 2) const;
    std::vector<int> immediate_wins(int side, const std::vector<int> &candidates) const;
    int fork_count(int side) const;
    int pattern_priority(int index, int side) const;
    std::vector<int> ordered(const std::vector<int> &moves, int side,
                             int limit, int previous_best = -1) const;
    int static_value(int side) const;
    bool limit_reached();
    bool prove_four(int side, int remaining, bool restrict_root,
                    std::vector<int> &variation);
    int tactical_leaf(int side, int ply, int remaining_forced);
    int negamax(int side, int depth, int alpha, int beta, int last, int ply);
};
}
