#pragma once
#include "board.hpp"
#include <chrono>
#include <cstdint>

namespace eclipse {
class Search {
public:
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
