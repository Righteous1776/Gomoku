#include "search.hpp"
#include <algorithm>
#include <array>
#include <cstdint>
#include <cstdlib>
#include <iostream>
#include <stdexcept>
#include <vector>

#define CHECK(x) do { if (!(x)) throw std::runtime_error("Candidate coverage regression: " #x); } while (0)
using eclipse::CandidateCoverage;
using eclipse::kCells;
using eclipse::kSide;

static std::vector<int> original_neighbors(
    const std::array<std::uint8_t, kCells> &cells, int radius) {
    if (std::all_of(cells.begin(), cells.end(),
                    [](std::uint8_t c) { return c == 0; }))
        return {112};
    std::array<bool, kCells> touched{};
    for (int i = 0; i < kCells; ++i) {
        if (!cells[i]) continue;
        const int r = i / kSide, c = i % kSide;
        for (int dr = -radius; dr <= radius; ++dr)
            for (int dc = -radius; dc <= radius; ++dc) {
                const int rr = r + dr, cc = c + dc;
                if (rr < 0 || rr >= kSide || cc < 0 || cc >= kSide)
                    continue;
                const int index = rr * kSide + cc;
                if (!cells[index]) touched[index] = true;
            }
    }
    std::vector<int> result;
    for (int i = 0; i < kCells; ++i)
        if (touched[i]) result.push_back(i);
    return result;
}

static void verify(const CandidateCoverage &frontier,
    const std::array<std::uint8_t, kCells> &cells, int radius) {
    CHECK(frontier.candidates(cells) == original_neighbors(cells, radius));
    // Also verify counts at EVERY square, including occupied squares:
    // caches must remain correct after both hypothetical play and unplay.
    for (int i = 0; i < kCells; ++i) {
        const int r = i / kSide, c = i % kSide;
        int count = 0;
        for (int j = 0; j < kCells; ++j) {
            if (!cells[j]) continue;
            if (std::abs(r - j / kSide) <= radius &&
                std::abs(c - j % kSide) <= radius) ++count;
        }
        CHECK(frontier.coverage(i) == count);
    }
}

int main() {
    for (int radius : {1, 2, 3, 5}) {
        std::array<std::uint8_t, kCells> cells{};
        CandidateCoverage frontier;
        frontier.reset(radius, cells);
        verify(frontier, cells, radius);
        // Include corners, central intersection and connected/isolated
        // stones. Stable pseudo-random sequence never uses owner records.
        std::vector<int> move_order = {0, 224, 14, 210, 112, 111, 113};
        std::uint32_t rng = 0xA57A2026u;
        for (int k = 0; k < 92; ++k) {
            rng = rng * 1664525u + 1013904223u;
            const int chosen = static_cast<int>(rng % kCells);
            if (std::find(move_order.begin(), move_order.end(), chosen) ==
                move_order.end())
                move_order.push_back(chosen);
        }
        for (std::size_t n = 0; n < move_order.size(); ++n) {
            const int index = move_order[n];
            CHECK(cells[index] == 0);
            cells[index] = static_cast<std::uint8_t>(1 + n % 2);
            frontier.add(index);
            verify(frontier, cells, radius);
        }
        while (!move_order.empty()) {
            const int index = move_order.back();
            move_order.pop_back();
            CHECK(cells[index] != 0);
            cells[index] = 0;
            frontier.remove(index);
            verify(frontier, cells, radius);
        }
        CHECK(frontier.candidates(cells).size() == 1);
        CHECK(frontier.candidates(cells)[0] == 112);
    }
    std::cout << "Exact candidate frontier: 4 radii, 4 corners, "
                 "random 200+ move/unmove snapshots PASS\n";
    return 0;
}
