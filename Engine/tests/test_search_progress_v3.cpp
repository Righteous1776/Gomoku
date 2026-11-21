#include "eclipse_c_api.h"
#include <atomic>
#include <chrono>
#include <iostream>
#include <memory>
#include <stdexcept>
#include <thread>
#define CHECK(x) do { if (!(x)) throw std::runtime_error("V3 telemetry: " #x); } while (0)
using Owner = std::unique_ptr<EGEngine, decltype(&eg_destroy)>;
int main() {
    CHECK(eg_search_progress_abi_version() == 3);
    Owner e(eg_create(), eg_destroy);
    CHECK(e != nullptr);
    CHECK(eg_play(e.get(), 112) == 1 && eg_play(e.get(), 97) == 1);
    EGSearchProgressV3 sample{};
    sample.size_bytes = sizeof(sample);
    CHECK(eg_read_search_progress_v3(e.get(), &sample) == 1);
    CHECK(sample.running == 0 && sample.move_count == 0);
    EGComputePolicyV2 policy{};
    policy.size_bytes = sizeof(policy);
    policy.mode = EG_COMPUTE_MODE_BUDGETED;
    policy.max_wall_time_ms = 30000;
    policy.max_depth = 40;
    policy.root_width = 24;
    policy.reply_width = 16;
    policy.continuation_width = 8;
    policy.forced_line_depth = 0;
    policy.candidate_radius = 2;
    EGComputeRunV2 output{};
    output.size_bytes = sizeof(output);
    std::atomic<int> success{-1};
    const auto began = std::chrono::steady_clock::now();
    std::thread worker([&] {
        success.store(eg_analyze_compute_policy_v2(
            e.get(), &policy, nullptr, 0, nullptr, 0, &output));
    });
    bool observed = false;
    for (int j=0; j<20; ++j) {
        std::this_thread::sleep_for(std::chrono::milliseconds(15));
        if (eg_read_search_progress_v3(e.get(), &sample) == 1 &&
            sample.running == 1 && sample.move_count > 0) {
            CHECK(sample.nodes > 0);
            CHECK(sample.root_move >= 0 && sample.root_move < 225);
            CHECK(sample.root_move != 112 && sample.root_move != 97);
            observed = true;
            break;
        }
    }
    eg_request_search_finish_v3(e.get());
    worker.join();
    CHECK(success.load() == 1);
    CHECK(output.search.move >= 0 && output.search.move < 225);
    CHECK(output.search.move != 112 && output.search.move != 97);
    CHECK(output.search.reason == EG_SEARCH_REASON_USER_FINISH ||
          output.search.reason == EG_SEARCH_REASON_COMPLETE ||
          output.search.reason == EG_SEARCH_REASON_FORCED_WIN);
    CHECK(eg_ply_count(e.get()) == 2);
    CHECK(eg_read_search_progress_v3(e.get(), &sample) == 1);
    CHECK(sample.running == 0);
    CHECK(std::chrono::duration_cast<std::chrono::seconds>(
        std::chrono::steady_clock::now() - began).count() < 10);
    std::cout << "Real C++ search V3 telemetry; sample=" << observed << " PASS\n";
    return 0;
}
