#pragma once
#include "board.hpp"
#include <chrono>
#include <cstdint>

namespace eclipse {
// Experimental search telemetry. NOT native Swift ECLIPSE strength parity.
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

class Search {
public:
    SearchResult analyze(const Board &root, int milliseconds);
    int best_move(const Board &root,int milliseconds);
private:
    using Clock = std::chrono::steady_clock;
    Clock::time_point deadline_{};
    std::uint64_t nodes_ = 0;
    bool timed_out_ = false;
    std::int64_t negamax(const Board &b,int depth,std::int64_t alpha,std::int64_t beta);
    std::vector<int> sorted_candidates(const Board &b,int limit);
    bool out_of_time();
};
}
