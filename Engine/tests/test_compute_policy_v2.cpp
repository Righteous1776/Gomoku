#include "eclipse_c_api.h"
#include <array>
#include <atomic>
#include <chrono>
#include <cstdint>
#include <cstring>
#include <iostream>
#include <memory>
#include <stdexcept>
#include <thread>

#define CHECK(expr) do { if (!(expr)) throw std::runtime_error("R17 policy ABI failure: " #expr); } while (false)

using Owner = std::unique_ptr<EGEngine, decltype(&eg_destroy)>;

static EGComputePolicyV2 adaptive() {
    EGComputePolicyV2 c{};
    c.size_bytes = sizeof(c);
    c.mode = EG_COMPUTE_MODE_ADAPTIVE;
    c.max_wall_time_ms = 0; // Training Agent: NO wall-clock cap.
    c.max_nodes = 0;        // Training Agent: NO node cap.
    c.max_depth = 15;       // Not silently reduced to the old C++ max of 9.
    c.root_width = 60;      // Not silently reduced to 18.
    c.reply_width = 40;     // Not silently reduced to 14.
    c.continuation_width = 30;
    c.forced_line_depth = 10;
    c.candidate_radius = 5; // Not silently reduced to radius 3.
    return c;
}
static EGComputeRunV2 prepared() {
    EGComputeRunV2 r{};
    r.size_bytes = sizeof(r);
    return r;
}
static void urgent_win(EGEngine *engine) {
    for (int i=0; i<4; ++i) {
        CHECK(eg_play(engine,i) == 1);
        CHECK(eg_play(engine,15+i) == 1);
    }
}
int main() {
    CHECK(eg_compute_policy_abi_version() == 2);
    Owner engine(eg_create(), eg_destroy);
    CHECK(engine != nullptr);
    urgent_win(engine.get());

    auto policy = adaptive();
    auto run = prepared();
    // An actual search, not a label-only policy return. Never changes board.
    CHECK(eg_analyze_compute_policy_v2(engine.get(), &policy,
          nullptr, 0, nullptr, 0, &run) == 1);
    CHECK(run.search.move == 4);
    CHECK(run.search.reason == EG_SEARCH_REASON_FORCED_WIN);
    CHECK(run.search.size_bytes == sizeof(EGSearchDiagnosticsV1));
    CHECK(run.applied_policy.size_bytes == sizeof(EGComputePolicyV2));
    CHECK(std::memcmp(&policy,&run.applied_policy,sizeof(policy)) == 0);
    CHECK(eg_ply_count(engine.get()) == 8);

    // Arbitrary trainer budget >> previous hardcoded 20s. Early forced win.
    policy.mode = EG_COMPUTE_MODE_BUDGETED;
    policy.max_wall_time_ms = 123456;
    policy.max_nodes = 70000000;
    CHECK(eg_analyze_compute_policy_v2(engine.get(), &policy,
          nullptr, 0, nullptr, 0, &run) == 1);
    CHECK(run.search.move == 4);
    CHECK(run.applied_policy.max_wall_time_ms == 123456);
    CHECK(run.applied_policy.max_nodes == 70000000);

    // Reject badly formed policies without even touching previous output.
    const auto earlier = run;
    policy.size_bytes = 0;
    CHECK(eg_analyze_compute_policy_v2(engine.get(), &policy,
          nullptr, 0, nullptr, 0, &run) == 0);
    CHECK(std::memcmp(&run,&earlier,sizeof(run)) == 0);
    policy = adaptive();
    policy.max_depth = 226;
    CHECK(eg_analyze_compute_policy_v2(engine.get(), &policy,
          nullptr, 0, nullptr, 0, &run) == 0);
    CHECK(std::memcmp(&run,&earlier,sizeof(run)) == 0);
    policy = adaptive();
    policy.candidate_radius = 15;
    CHECK(eg_analyze_compute_policy_v2(engine.get(), &policy,
          nullptr, 0, nullptr, 0, &run) == 0);
    CHECK(std::memcmp(&run,&earlier,sizeof(run)) == 0);
    policy = adaptive();
    policy.mode = EG_COMPUTE_MODE_BUDGETED; // 0ms incompatible with BUDGETED.
    CHECK(eg_analyze_compute_policy_v2(engine.get(), &policy,
          nullptr, 0, nullptr, 0, &run) == 0);
    CHECK(std::memcmp(&run,&earlier,sizeof(run)) == 0);
    policy = adaptive();

    // Roots provided by Swift may rank legal alternatives, not exclude a
    // compulsory win. A disallowed winning root MUST fail closed.
    std::array<std::uint8_t,225> allowed{};
    allowed.fill(1);
    std::array<std::int32_t,225> bonus{};
    bonus[9] = 2000;
    CHECK(eg_analyze_compute_policy_v2(engine.get(), &policy,
          allowed.data(),225,bonus.data(),225,&run) == 1);
    CHECK(run.search.move == 4);
    allowed[4] = 0;
    const auto unchanged = run;
    CHECK(eg_analyze_compute_policy_v2(engine.get(), &policy,
          allowed.data(),225,bonus.data(),225,&run) == 0);
    CHECK(std::memcmp(&run,&unchanged,sizeof(run)) == 0);
    allowed[4] = 1;
    bonus[9] = 2001;
    CHECK(eg_analyze_compute_policy_v2(engine.get(), &policy,
          allowed.data(),225,bonus.data(),225,&run) == 0);
    CHECK(std::memcmp(&run,&unchanged,sizeof(run)) == 0);

    // Run a quiet nonterminal board at trainer-selected depth one and two.
    eg_reset(engine.get());
    CHECK(eg_play(engine.get(),112) == 1);
    CHECK(eg_play(engine.get(),97) == 1);
    policy = adaptive();
    policy.max_depth = 1;
    policy.root_width = 2;
    policy.reply_width = 2;
    policy.continuation_width = 1;
    policy.forced_line_depth = 0;
    CHECK(eg_analyze_compute_policy_v2(engine.get(), &policy,
          nullptr,0,nullptr,0,&run) == 1);
    CHECK(run.search.move >= 0 && run.search.move < 225);
    CHECK(run.search.completed_depth == 1);
    CHECK(run.applied_policy.root_width == 2);
    CHECK(run.applied_policy.forced_line_depth == 0);
    CHECK(eg_ply_count(engine.get()) == 2);

    // Concurrent cancellation of open-ended research search must be safe.
    policy = adaptive();
    policy.max_depth = 225;
    policy.root_width = 200;
    policy.reply_width = 150;
    policy.continuation_width = 100;
    policy.forced_line_depth = 30;
    std::atomic<int> status{-1};
    EGComputeRunV2 cancelled_run = prepared();
    std::thread worker([&] {
        status.store(eg_analyze_compute_policy_v2(engine.get(),&policy,
              nullptr,0,nullptr,0,&cancelled_run),std::memory_order_release);
    });
    std::this_thread::sleep_for(std::chrono::milliseconds(25));
    eg_cancel_search_v2(engine.get());
    worker.join();
    // Search may finish a certified winning root before cancellation; either
    // way, it must not corrupt game state or cross the C ABI with an exception.
    CHECK(status.load() == 0 || status.load() == 1);
    CHECK(eg_ply_count(engine.get()) == 2);
    std::array<std::uint8_t,225> board{};
    CHECK(eg_copy_board(engine.get(),board.data(),225) == 225);
    CHECK(board[112] == 1 && board[97] == 2);

    std::cout << "C++ trainer policy V2 ABI: exact limits, long/unlimited, "
                 "cancellation, tactical protections PASSED\n";
    return 0;
}
