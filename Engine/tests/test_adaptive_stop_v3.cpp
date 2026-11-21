#include "eclipse_c_api.h"
#include <array>
#include <chrono>
#include <cstring>
#include <iostream>
#include <memory>
#include <stdexcept>

#define CHECK(x) do { if (!(x)) throw std::runtime_error("Adaptive V3 failed: " #x); } while(false)
using Owner = std::unique_ptr<EGEngine, decltype(&eg_destroy)>;

static EGComputePolicyV2 trainer_policy(int depth = 8) {
    EGComputePolicyV2 p{};
    p.size_bytes = sizeof(p);
    p.mode = EG_COMPUTE_MODE_ADAPTIVE;
    p.max_wall_time_ms = 0;
    p.max_nodes = 0;
    p.max_depth = depth;
    p.root_width = 5;
    p.reply_width = 3;
    p.continuation_width = 2;
    p.forced_line_depth = 0;
    p.candidate_radius = 2;
    return p;
}
static EGAdaptiveStopConfigV3 stopping() {
    EGAdaptiveStopConfigV3 s{};
    s.size_bytes = sizeof(s);
    s.minimum_depth = 2;
    s.stable_rounds = 2;
    s.minimum_score_gap = 100000;
    s.clear_budget_ms = 1000;
    s.uncertain_budget_ms = 2000;
    s.complex_budget_ms = 3500;
    return s;
}
static EGAdaptiveRunV3 out_run() {
    EGAdaptiveRunV3 r{};
    r.size_bytes = sizeof(r);
    return r;
}
int main() {
    CHECK(eg_adaptive_stop_abi_version() == 3);
    Owner e(eg_create(), eg_destroy);
    CHECK(e != nullptr);
    auto p = trainer_policy();
    auto s = stopping();
    auto result = out_run();

    // Immediate tactical certificates outrank any cost heuristics.
    for (int i = 0; i < 4; ++i) {
        CHECK(eg_play(e.get(), i) == 1);
        CHECK(eg_play(e.get(), 15+i) == 1);
    }
    CHECK(eg_analyze_compute_policy_v3(e.get(), &p, &s,
        nullptr, 0, nullptr, 0, &result) == 1);
    CHECK(result.base.search.move == 4);
    CHECK(result.base.search.reason == EG_SEARCH_REASON_FORCED_WIN);
    CHECK(std::memcmp(&result.base.applied_policy, &p, sizeof(p)) == 0);
    CHECK(std::memcmp(&result.applied_stopping, &s, sizeof(s)) == 0);
    CHECK(result.predicted_next_depth_ms == 0);
    CHECK(eg_ply_count(e.get()) == 8);

    // All failed input must leave caller output untouched, including V2
    // trainer policy, new stopping controls and native decision metadata.
    const auto previous = result;
    s.complex_budget_ms = 0;
    CHECK(eg_analyze_compute_policy_v3(e.get(), &p, &s,
        nullptr,0,nullptr,0,&result) == 0);
    CHECK(std::memcmp(&result, &previous, sizeof(result)) == 0);
    s = stopping();
    s.stable_rounds = 1;
    CHECK(eg_analyze_compute_policy_v3(e.get(), &p, &s,
        nullptr,0,nullptr,0,&result) == 0);
    CHECK(std::memcmp(&result, &previous, sizeof(result)) == 0);
    s = stopping();
    p.mode = EG_COMPUTE_MODE_BUDGETED;
    p.max_wall_time_ms = 200;
    // Explicit V3 must not override the trainer's shorter hard ceiling.
    CHECK(eg_analyze_compute_policy_v3(e.get(), &p, &s,
        nullptr,0,nullptr,0,&result) == 0);
    CHECK(std::memcmp(&result, &previous, sizeof(result)) == 0);
    p.max_wall_time_ms = 3500;
    // The same finite trainer budget CAN opt in to V3 and retains its
    // exact approved policy bytes. This is the actual Astra/Sol V9 mode.
    result = out_run();
    CHECK(eg_analyze_compute_policy_v3(e.get(), &p, &s,
        nullptr,0,nullptr,0,&result) == 1);
    CHECK(std::memcmp(&result.base.applied_policy, &p, sizeof(p)) == 0);
    CHECK(std::memcmp(&result.applied_stopping, &s, sizeof(s)) == 0);
    CHECK(result.base.search.reason == EG_SEARCH_REASON_FORCED_WIN);

    // Mandatory defense may not be bypassed to claim a quicker stable move.
    eg_reset(e.get());
    for (int i=0; i<4; ++i) {
        CHECK(eg_play(e.get(), i*2) == 1);
        CHECK(eg_play(e.get(), 15+i) == 1);
    }
    p = trainer_policy();
    s = stopping();
    result = out_run();
    CHECK(eg_analyze_compute_policy_v3(e.get(), &p, &s,
        nullptr,0,nullptr,0,&result) == 1);
    CHECK(result.base.search.move == 19);
    CHECK(result.base.search.reason == EG_SEARCH_REASON_FORCED_BLOCK);
    CHECK(eg_ply_count(e.get()) == 8);

    // A single permitted root is an honest narrow decision (NOT certified
    // mate). Stable completed depths can end before the trainer max depth.
    eg_reset(e.get());
    CHECK(eg_play(e.get(), 112) == 1);
    CHECK(eg_play(e.get(), 97) == 1);
    p = trainer_policy(8);
    s = stopping();
    std::array<uint8_t, 225> allowed{};
    allowed[111] = 1;
    std::array<int32_t, 225> bonus{};
    result = out_run();
    CHECK(eg_analyze_compute_policy_v3(e.get(), &p, &s,
        allowed.data(),225, bonus.data(),225, &result) == 1);
    CHECK(result.base.search.move == 111);
    CHECK(result.base.search.completed_depth >= s.minimum_depth);
    CHECK(result.base.search.completed_depth < p.max_depth);
    CHECK(result.base.search.reason == EG_SEARCH_REASON_ADAPTIVE_CONVERGED);
    CHECK(result.stable_rounds_observed >= s.stable_rounds);
    CHECK(result.complexity_tier >= 0 && result.complexity_tier <= 2);
    CHECK(result.predicted_next_depth_ms > 0);
    CHECK(eg_ply_count(e.get()) == 2);

    // Legacy V2 explicitly remains the original semantics and ABI.
    p.max_depth = 1;
    EGComputeRunV2 legacy{};
    legacy.size_bytes = sizeof(legacy);
    CHECK(eg_analyze_compute_policy_v2(e.get(), &p,
        allowed.data(),225, bonus.data(),225, &legacy) == 1);
    CHECK(legacy.search.completed_depth == 1);
    CHECK(legacy.search.reason == EG_SEARCH_REASON_COMPLETE);
    CHECK(legacy.applied_policy.max_wall_time_ms == 0);

    // The V3 hard ceiling cannot silently become the V2 0ms infinity
    // convention even for a trainer asking for depth=225 / broad replies.
    p = trainer_policy(225);
    p.root_width = 120;
    p.reply_width = 60;
    p.continuation_width = 30;
    p.forced_line_depth = 30;
    s = stopping();
    s.minimum_depth = 3;
    s.stable_rounds = 3;
    s.clear_budget_ms = 2;
    s.uncertain_budget_ms = 5;
    s.complex_budget_ms = 15;
    result = out_run();
    const auto start = std::chrono::steady_clock::now();
    CHECK(eg_analyze_compute_policy_v3(e.get(), &p, &s,
        nullptr,0,nullptr,0,&result) == 1);
    const auto elapsed = std::chrono::duration_cast<
        std::chrono::milliseconds>(
        std::chrono::steady_clock::now() - start).count();
    CHECK(elapsed < 4000); // Broad CI safety watchdog, not claimed 15ms SLA.
    CHECK(result.base.search.move >= 0 && result.base.search.move < 225);
    CHECK(result.base.search.completed_depth <= p.max_depth);
    CHECK(eg_ply_count(e.get()) == 2);
    std::cout << "Adaptive V3: legal tactical priority, verified convergence, "
                 "native cost evidence, V2 compatibility PASS\n";
}
