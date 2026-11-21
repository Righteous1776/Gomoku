#include "search.hpp"
#include <algorithm>
#include <array>
#include <cstdint>
#include <iostream>
#include <stdexcept>
#include <vector>

#define CHECK(x) do { if (!(x)) throw std::runtime_error("Five-window exactness: " #x); } while (0)
using eclipse::FiveWindowScore;
using eclipse::kCells;
using eclipse::kSide;

constexpr int kAxes[4][2] = {{1, 0}, {0, 1}, {1, 1}, {1, -1}};
constexpr int kWeight[6] = {0, 2, 28, 900, 45000, 900000};
static bool inside(int row, int col) {
    return row >= 0 && row < kSide && col >= 0 && col < kSide;
}
static int reference_score(const std::array<std::uint8_t, kCells> &board,
                           int side) {
    int black = 0, white = 0;
    for (const auto &axis : kAxes)
        for (int row = 0; row < kSide; ++row)
            for (int col = 0; col < kSide; ++col) {
                if (!inside(row + 4 * axis[0], col + 4 * axis[1]))
                    continue;
                int b = 0, w = 0;
                for (int step = 0; step < 5; ++step) {
                    const int index = (row + step * axis[0]) * kSide
                                    + col + step * axis[1];
                    b += board[index] == 1;
                    w += board[index] == 2;
                }
                if (w == 0) black += kWeight[b];
                if (b == 0) white += kWeight[w];
            }
    return side == 1 ? black - white : white - black;
}
static bool reference_creates_four(
    const std::array<std::uint8_t, kCells> &board, int index, int side) {
    if (board[index] != 0) return false;
    const int row = index / kSide, col = index % kSide;
    for (const auto &axis : kAxes) {
        for (int offset = 0; offset < 5; ++offset) {
            const int start_r = row - offset * axis[0];
            const int start_c = col - offset * axis[1];
            if (!inside(start_r, start_c) ||
                !inside(start_r + 4 * axis[0], start_c + 4 * axis[1]))
                continue;
            int own = 0, enemy = 0;
            for (int step = 0; step < 5; ++step) {
                const int cell = (start_r + step * axis[0]) * kSide +
                                  start_c + step * axis[1];
                own += board[cell] == side;
                enemy += board[cell] == (3 - side);
            }
            if (enemy == 0 && own == 3) return true;
        }
    }
    return false;
}
static void verify(const FiveWindowScore &cache,
                   const std::array<std::uint8_t, kCells> &board,
                   bool full_four_check) {
    CHECK(cache.raw_score(1) == reference_score(board, 1));
    CHECK(cache.raw_score(2) == reference_score(board, 2));
    if (!full_four_check) return;
    for (int index = 0; index < kCells; ++index) {
        if (board[index] != 0) continue;
        CHECK(cache.creates_four(index, 1) ==
              reference_creates_four(board, index, 1));
        CHECK(cache.creates_four(index, 2) ==
              reference_creates_four(board, index, 2));
    }
}

int main() {
    FiveWindowScore cache;
    std::array<std::uint8_t, kCells> board{};
    cache.reset(board);
    verify(cache, board, true);
    std::vector<int> moves = {0, 224, 14, 210, 112, 111, 113, 97, 127};
    std::uint32_t random = 0x20261121u;
    for (int i = 0; i < 90; ++i) {
        random = random * 1664525u + 1013904223u;
        const int index = static_cast<int>(random % kCells);
        if (std::find(moves.begin(), moves.end(), index) == moves.end())
            moves.push_back(index);
    }
    for (std::size_t i = 0; i < moves.size(); ++i) {
        const int index = moves[i];
        CHECK(board[index] == 0);
        const int side = 1 + static_cast<int>(i % 2);
        board[index] = static_cast<std::uint8_t>(side);
        cache.add(index, side);
        verify(cache, board, i % 7 == 0);
    }
    // Reverse every move, including positions near all 4 edges.
    while (!moves.empty()) {
        const int index = moves.back();
        moves.pop_back();
        const int side = board[index];
        CHECK(side == 1 || side == 2);
        board[index] = 0;
        cache.remove(index, side);
        verify(cache, board, moves.size() % 7 == 0);
    }
    verify(cache, board, true);
    std::cout << "Exact five-window score and forcing-four filter: PASS\n";
}
