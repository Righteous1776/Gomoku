#include "eclipse_c_api.h"
#include <atomic>
#include <chrono>
#include <cstdint>
#include <cstring>
#include <iostream>
#include <memory>
#include <stdexcept>
#include <thread>

#define CHECK(x) do { if (!(x)) throw std::runtime_error("live telemetry: " #x); } while (false)
using EngineOwner = std::unique_ptr<EGEngine, decltype(&eg_destroy)>;

static EGSearchLiveSnapshotV1 read(EGEngine *e) {
    EGSearchLiveSnapshotV1 out{};
    out.size_bytes = sizeof(out);
    CHECK(eg_read_live_search_v1(e, &out) == 1);
    CHECK(out.size_bytes == sizeof(out));
    CHECK(out.reserved == 0);
    CHECK(out.completed_depth >= 0);
    CHECK(out.best_move >= -1 && out.best_move < 225);
    CHECK(out.elapsed_ms >= 0);
    return out;
}
static EGComputePolicyV2 policy() {
    EGComputePolicyV2 p{};
    p.size_bytes = sizeof(p);
    p.mode = EG_COMPUTE_MODE_ADAPTIVE;
    p.max_depth = 225;
    p.root_width = 24;
    p.reply_width = 16;
    p.continuation_width = 12;
    p.forced_line_depth = 0;
    p.candidate_radius = 2;
    return p;
}
int main() {
    EngineOwner e(eg_create(), eg_destroy);
    CHECK(e != nullptr);
    auto idle = read(e.get());
    CHECK(idle.state == EG_LIVE_SEARCH_IDLE);
    CHECK(idle.search_serial == 0);
    CHECK(idle.best_move == -1);
    CHECK(idle.reason == -1);

    // Failed API reads are non-destructive and cannot leak partial data.
    EGSearchLiveSnapshotV1 invalid{};
    invalid.size_bytes = 0;
    invalid.reason = 123456;
    CHECK(eg_read_live_search_v1(e.get(), &invalid) == 0);
    CHECK(invalid.reason == 123456);

    // One truly forced move, from the native engine, without a rerun.
    for (int i = 0; i < 4; ++i) {
        CHECK(eg_play(e.get(), i) == 1);
        CHECK(eg_play(e.get(), 15+i) == 1);
    }
    auto p = policy();
    EGComputeRunV2 result{};
    result.size_bytes = sizeof(result);
    CHECK(eg_analyze_compute_policy_v2(e.get(), &p,
          nullptr, 0, nullptr, 0, &result) == 1);
    const auto certified = read(e.get());
    CHECK(certified.state == EG_LIVE_SEARCH_COMPLETE);
    CHECK(certified.search_serial == 1);
    CHECK(certified.best_move == result.search.move);
    CHECK(certified.best_move == 4);
    CHECK(certified.reason == EG_SEARCH_REASON_FORCED_WIN);
    CHECK(certified.visited_nodes == result.search.nodes);

    // Board mutation invalidates completed search facts, not its serial.
    eg_reset(e.get());
    auto cleared = read(e.get());
    CHECK(cleared.state == EG_LIVE_SEARCH_IDLE);
    CHECK(cleared.best_move == -1);
    CHECK(cleared.visited_nodes == 0);
    CHECK(cleared.search_serial == certified.search_serial);

    CHECK(eg_play(e.get(), 112) == 1);
    CHECK(eg_play(e.get(), 97) == 1);
    std::atomic<bool> finished{false};
    std::atomic<int> outcome{-1};
    EGComputeRunV2 async_run{};
    async_run.size_bytes = sizeof(async_run);
    std::thread worker([&] {
        outcome.store(eg_analyze_compute_policy_v2(e.get(), &p,
            nullptr, 0, nullptr, 0, &async_run));
        finished.store(true);
    });
    bool saw_running = false;
    bool coherent = true;
    std::uint64_t previous_nodes = 0;
    std::int64_t previous_elapsed = 0;
    for (int i = 0; i < 100; ++i) {
        const auto snap = read(e.get());
        if (snap.state == EG_LIVE_SEARCH_RUNNING) {
            saw_running = true;
            coherent = coherent && snap.search_serial == 2
                && snap.reason == -1
                && snap.visited_nodes >= previous_nodes
                && snap.elapsed_ms >= previous_elapsed;
            previous_nodes = snap.visited_nodes;
            previous_elapsed = snap.elapsed_ms;
        }
        if (finished.load()) break;
        std::this_thread::sleep_for(std::chrono::milliseconds(2));
    }
    eg_cancel_search_v2(e.get());
    worker.join();
    CHECK(coherent);
    CHECK(saw_running || outcome.load() == 1); // fast completed search is valid
    CHECK(outcome.load() == 0 || outcome.load() == 1);
    const auto final = read(e.get());
    CHECK(final.search_serial == 2);
    CHECK(final.state == EG_LIVE_SEARCH_CANCELLED
          || final.state == EG_LIVE_SEARCH_COMPLETE);
    CHECK(final.state == EG_LIVE_SEARCH_CANCELLED
          ? final.reason == EG_SEARCH_REASON_CANCELLED
          : final.reason >= 0);

    // A stale native move cannot survive the next legal ply.
    if (final.state == EG_LIVE_SEARCH_COMPLETE) {
        CHECK(eg_play(e.get(), final.best_move) == 1);
        CHECK(read(e.get()).state == EG_LIVE_SEARCH_IDLE);
    }
    CHECK(eg_ply_count(e.get()) >= 2);

    // Actual shortlisted root rank comes from the same native analysis, not
    // from a duplicate scorer or placeholder win-probability heatmap.
    eg_reset(e.get());
    CHECK(eg_play(e.get(), 112) == 1);
    CHECK(eg_play(e.get(), 97) == 1);
    p = policy();
    p.max_depth = 1;
    p.root_width = 5;
    p.reply_width = 3;
    EGComputeRunV2 ranking_run{};
    ranking_run.size_bytes = sizeof(ranking_run);
    CHECK(eg_analyze_compute_policy_v2(e.get(), &p,
          nullptr, 0, nullptr, 0, &ranking_run) == 1);
    EGRankedRootsSnapshotV1 ranks{};
    ranks.size_bytes = sizeof(ranks);
    CHECK(eg_read_ranked_roots_v1(e.get(), &ranks) == 1);
    CHECK(ranks.search_serial == read(e.get()).search_serial);
    CHECK(ranks.count > 0 && ranks.count <= 5);
    std::array<bool, 225> seen{};
    for (unsigned i = 0; i < ranks.count; ++i) {
        const auto move = ranks.moves[i];
        CHECK(move >= 0 && move < 225 && move != 112 && move != 97);
        CHECK(!seen[move]);
        seen[move] = true;
    }
    for (unsigned i=ranks.count; i<EG_LIVE_RANKED_ROOTS_MAX; ++i)
        CHECK(ranks.moves[i] == -1);

    EGPVPrefixSnapshotV1 pv{};
    pv.size_bytes = sizeof(pv);
    CHECK(eg_read_pv_prefix_v1(e.get(), &pv) == 1);
    CHECK(pv.search_serial == ranks.search_serial);
    CHECK(pv.completed_depth == ranking_run.search.completed_depth);
    CHECK(pv.count >= 1 && pv.count <= EG_LIVE_PV_PREFIX_MAX);
    CHECK(pv.count <= static_cast<unsigned>(pv.completed_depth));
    CHECK(pv.moves[0] == ranking_run.search.move);
    std::array<bool,225> used{};
    used[112] = true;
    used[97] = true;
    for (unsigned i=0; i<pv.count; ++i) {
        CHECK(pv.moves[i] >= 0 && pv.moves[i] < 225);
        CHECK(!used[pv.moves[i]]);
        used[pv.moves[i]] = true;
    }
    for (unsigned i=pv.count; i<EG_LIVE_PV_PREFIX_MAX; ++i)
        CHECK(pv.moves[i] == -1);
    eg_reset(e.get());
    ranks.size_bytes = sizeof(ranks);
    CHECK(eg_read_ranked_roots_v1(e.get(), &ranks) == 1);
    CHECK(ranks.count == 0);
    pv.size_bytes = sizeof(pv);
    CHECK(eg_read_pv_prefix_v1(e.get(), &pv) == 1);
    CHECK(pv.count == 0 && pv.completed_depth == 0);
    std::cout << "ECLIPSE Stage B/C2/C3 live ABI: atomic polling, rank legality, serial, invalidation, "
                 "native proof and cancellation PASS\n";
}
