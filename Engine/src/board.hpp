#pragma once
#include <array>
#include <cstdint>
#include <vector>

namespace eclipse {
constexpr int kSide = 15;
constexpr int kCells = kSide * kSide;

class Board {
public:
    std::array<std::uint8_t, kCells> cells{};
    int turn = 1;
    int outcome = 0;
    std::vector<int> moves;

    bool play(int index);
    bool undo();
    void reset();
    bool legal(int index) const;
    bool winning_move(int index, int player) const;
    bool five_at(int index, int player) const;
    std::vector<int> candidates(int radius=2) const;
    std::int64_t evaluate(int player) const;
};
}
