#include "eclipse_c_api.h"
#include "board.hpp"
#include "search.hpp"
#include <algorithm>
#include <array>
#include <atomic>
#include <chrono>
#include <cstring>
#include <limits>
#include <new>

struct EGEngine {
    eclipse::Board board;
    std::atomic<bool> cancelled{false};
    // Sequence-protected atomics: C++ search owns all writes, UI only reads.
    // No personal board state or speculative score is stored here.
    std::atomic<std::uint64_t> live_sequence{0};
    std::atomic<std::uint64_t> live_serial{0};
    std::atomic<std::uint64_t> live_nodes{0};
    std::atomic<std::uint32_t> live_state{EG_LIVE_SEARCH_IDLE};
    std::atomic<std::int32_t> live_depth{0};
    std::atomic<std::int32_t> live_best{-1};
    std::atomic<std::int32_t> live_reason{-1};
    std::atomic<std::int64_t> live_started_ns{0};
    std::atomic<std::int64_t> live_elapsed_ms{0};
    std::atomic<std::uint32_t> live_rank_count{0};
    std::array<std::atomic<std::int32_t>, EG_LIVE_RANKED_ROOTS_MAX> live_rank_moves{};
    std::atomic<std::uint32_t> live_pv_count{0};
    std::atomic<std::int32_t> live_pv_depth{0};
    std::array<std::atomic<std::int32_t>, EG_LIVE_PV_MAX> live_pv_moves{};
    // Explicit research-only V2 ranking selection (default R10).
    int research_ranker = EG_RESEARCH_RANKER_LEGACY;
    int verified_v9_model = 0;
};

namespace {
std::int64_t steady_now_ns() {
    return std::chrono::duration_cast<std::chrono::nanoseconds>(
        std::chrono::steady_clock::now().time_since_epoch()).count();
}
// One writer (the search call, or an idle mutator). Every payload field is
// atomic, so the reader's bounded seqlock retry has no C++ data race.
void publish_live(EGEngine *e, std::uint32_t state,
                  std::uint64_t nodes, std::int32_t depth,
                  std::int32_t best, std::int32_t reason,
                  std::int64_t elapsed_ms) {
    e->live_sequence.fetch_add(1);
    e->live_state.store(state);
    e->live_nodes.store(nodes);
    e->live_depth.store(depth);
    e->live_best.store(best);
    e->live_reason.store(reason);
    e->live_elapsed_ms.store(elapsed_ms);
    e->live_sequence.fetch_add(1);
}
void clear_live(EGEngine *e) {
    e->live_sequence.fetch_add(1);
    e->live_state.store(EG_LIVE_SEARCH_IDLE);
    e->live_nodes.store(0);
    e->live_depth.store(0);
    e->live_best.store(-1);
    e->live_reason.store(-1);
    e->live_elapsed_ms.store(0);
    e->live_rank_count.store(0);
    for (auto &index : e->live_rank_moves) index.store(-1);
    e->live_pv_count.store(0);
    e->live_pv_depth.store(0);
    for (auto &index : e->live_pv_moves) index.store(-1);
    e->live_sequence.fetch_add(1);
}
void publish_ranked(EGEngine *e, const std::vector<int> &ranked) {
    const auto count = std::min<std::size_t>(ranked.size(),
                                            EG_LIVE_RANKED_ROOTS_MAX);
    e->live_sequence.fetch_add(1);
    for (std::size_t i = 0; i < EG_LIVE_RANKED_ROOTS_MAX; ++i)
        e->live_rank_moves[i].store(i < count ? ranked[i] : -1);
    e->live_rank_count.store(static_cast<std::uint32_t>(count));
    e->live_sequence.fetch_add(1);
}
void publish_completed_pv(EGEngine *e, int depth,
                          const std::vector<int> &line) {
    const auto count = std::min<std::size_t>(line.size(), EG_LIVE_PV_MAX);
    e->live_sequence.fetch_add(1);
    for (std::size_t i=0; i<EG_LIVE_PV_MAX; ++i)
        e->live_pv_moves[i].store(i < count ? line[i] : -1);
    e->live_pv_depth.store(depth);
    e->live_pv_count.store(static_cast<std::uint32_t>(count));
    e->live_sequence.fetch_add(1);
}
} // namespace

extern "C" {
int eg_rules_abi_version(void){return EG_RULES_ABI_VERSION;}
int eg_rules_replay_v1(const int32_t *moves, int32_t count,
                       uint8_t *out225, int32_t capacity,
                       int32_t *out_to_move, int32_t *out_status) {
    if (!out225 || !out_to_move || !out_status || capacity < eclipse::kCells ||
        count < 0 || count > eclipse::kCells || (count && !moves)) return 0;
    eclipse::Board reference;
    for (int32_t i = 0; i < count; ++i) {
        if (!reference.play(moves[i])) return 0;
    }
    // Commit output only after verifying the COMPLETE history. An illegal
    // replay must never leak partial boards or mutate previous snapshots.
    std::copy(reference.cells.begin(), reference.cells.end(), out225);
    // Current C++ prototype flips the side even when the last move ends the
    // game. Swift GomokuState retains the last mover on terminal positions.
    *out_to_move = reference.outcome == 0
        ? reference.turn : (count % 2 == 1 ? 1 : 2);
    *out_status = reference.outcome;
    return 1;
}
EGEngine *eg_create(void){return new(std::nothrow) EGEngine{};}
void eg_destroy(EGEngine *e){delete e;}
void eg_reset(EGEngine *e){if(e){e->board.reset(); e->research_ranker = EG_RESEARCH_RANKER_LEGACY; e->verified_v9_model=0; clear_live(e);}}
int eg_play(EGEngine *e,int index){if(!e||!e->board.play(index))return 0;clear_live(e);return 1;}
int eg_undo(EGEngine *e){if(!e||!e->board.undo())return 0;clear_live(e);return 1;}
int eg_best_move(const EGEngine *e,int ms){if(!e)return -1;return eclipse::Search{}.best_move(e->board,ms);}
int eg_best_move_diagnostics_v1(const EGEngine *e, int ms,
                                 EGSearchDiagnosticsV1 *out) {
    if (!e || !out || out->size_bytes != sizeof(EGSearchDiagnosticsV1)) return 0;
    const auto search = eclipse::Search{}.analyze(e->board, ms);
    EGSearchDiagnosticsV1 snapshot{};
    snapshot.size_bytes = sizeof(EGSearchDiagnosticsV1);
    snapshot.move = search.move;
    snapshot.completed_depth = search.completed_depth;
    snapshot.elapsed_ms = search.elapsed_ms;
    snapshot.nodes = search.nodes;
    snapshot.reason = static_cast<int>(search.reason);
    *out = snapshot;
    return 1;
}
int eg_best_move_root_policy_v1(const EGEngine *e, int ms,
                                const uint8_t *allowed, int allowed_capacity,
                                const int32_t *bonuses, int bonus_capacity,
                                EGSearchDiagnosticsV1 *out) {
    if (!e || !allowed || !bonuses || !out ||
        out->size_bytes != sizeof(EGSearchDiagnosticsV1) ||
        allowed_capacity != eclipse::kCells ||
        bonus_capacity != eclipse::kCells) return 0;
    eclipse::RootPolicy policy{};
    for (int i = 0; i < eclipse::kCells; ++i) {
        if (allowed[i] > 1 || bonuses[i] < -2000 || bonuses[i] > 2000) return 0;
        policy.allowed[i] = allowed[i] == 1;
        policy.bonus[i] = bonuses[i];
    }
    const auto search = eclipse::Search{}.analyze(e->board, ms, &policy);
    if (search.move < 0 && e->board.outcome == 0) return 0;
    EGSearchDiagnosticsV1 snapshot{};
    snapshot.size_bytes = sizeof(EGSearchDiagnosticsV1);
    snapshot.move = search.move;
    snapshot.completed_depth = search.completed_depth;
    snapshot.elapsed_ms = search.elapsed_ms;
    snapshot.nodes = search.nodes;
    snapshot.reason = static_cast<int>(search.reason);
    *out = snapshot;
    return 1;
}
/* No R29/214-tree trainer artifact is compiled/loaded in THIS Git branch.
 * Fail closed rather than falsely identifying the frozen R10 ranker as new.
 * Training Agent will replace this identity implementation alongside an
 * actual compiled/loaded trained scorer, not by injecting a manifest string.
 */
int eg_active_trained_checkpoint_sha256_v2(char *out, int capacity) {
    (void)out;
    (void)capacity;
    return 0;
}
int eg_select_research_ranker_v3(EGEngine *e, int32_t ranker) {
    if (!e || ranker < EG_RESEARCH_RANKER_LEGACY ||
        ranker > EG_RESEARCH_RANKER_V9_SOL) return 0;
    e->research_ranker = ranker;
    e->verified_v9_model = 0; // Research selection never inherits production attestation.
    clear_live(e);
    return 1;
}
int eg_research_ranker_v3(const EGEngine *e) {
    return e ? e->research_ranker : -1;
}
// These are source-model SHA256 pins. The full C++ tree export is verified
// against the raw files in mandatory CI, not inferred from a model label.
static constexpr char kAstraV9LightGBMSHA[] =
    "d50190d02bf6ebd6f447d84a2920184964ac9cff1dcc0712b0076cec326a177d";
static constexpr char kSolV9LightGBMSHA[] =
    "074140fa99d52143ce3b887a553f1f11586973096baaada6476f97004e4b4fdd";
static const char *compiled_v9_sha(int model) {
    if (model == EG_RESEARCH_RANKER_V9_ASTRA) return kAstraV9LightGBMSHA;
    if (model == EG_RESEARCH_RANKER_V9_SOL) return kSolV9LightGBMSHA;
    return nullptr;
}
int eg_select_compiled_v9_model_v4(EGEngine *e, int32_t model,
                                    const char *expected_sha256) {
    const char *actual = compiled_v9_sha(model);
    if (!e || !actual || !expected_sha256 ||
        std::strncmp(actual, expected_sha256, 65) != 0) return 0;
    e->research_ranker = model;
    e->verified_v9_model = model;
    clear_live(e);
    return 1;
}
int eg_active_compiled_v9_sha256_v4(const EGEngine *e,
                                    char *out, int32_t capacity) {
    if (!e || !out || capacity < 65 ||
        e->verified_v9_model != e->research_ranker) return 0;
    const char *actual = compiled_v9_sha(e->verified_v9_model);
    if (!actual) return 0;
    std::memcpy(out, actual, 65);
    return 64;
}
int eg_compute_policy_abi_version(void) { return EG_COMPUTE_POLICY_ABI_VERSION; }
void eg_cancel_search_v2(EGEngine *e) {
    if (e) e->cancelled.store(true, std::memory_order_release);
}

int eg_read_live_search_v1(const EGEngine *e, EGSearchLiveSnapshotV1 *out) {
    if (!e || !out || out->size_bytes != sizeof(EGSearchLiveSnapshotV1))
        return 0;
    // A writer never waits for a reader. If the writer is interrupted while
    // the sequence is odd, fail closed without altering the caller's buffer.
    for (int tries = 0; tries < 32; ++tries) {
        const auto before = e->live_sequence.load();
        if (before & 1) continue;
        EGSearchLiveSnapshotV1 snapshot{};
        snapshot.size_bytes = sizeof(snapshot);
        snapshot.state = e->live_state.load();
        snapshot.search_serial = e->live_serial.load();
        snapshot.visited_nodes = e->live_nodes.load();
        snapshot.completed_depth = e->live_depth.load();
        snapshot.best_move = e->live_best.load();
        snapshot.reason = e->live_reason.load();
        const auto started_ns = e->live_started_ns.load();
        snapshot.elapsed_ms = snapshot.state == EG_LIVE_SEARCH_RUNNING
            && started_ns > 0
            ? std::max<std::int64_t>(0, (steady_now_ns() - started_ns) / 1000000)
            : e->live_elapsed_ms.load();
        const auto after = e->live_sequence.load();
        if (before == after && !(after & 1)) {
            *out = snapshot;
            return 1;
        }
    }
    return 0;
}

int eg_read_ranked_roots_v1(const EGEngine *e, EGRankedRootsSnapshotV1 *out) {
    if (!e || !out || out->size_bytes != sizeof(EGRankedRootsSnapshotV1))
        return 0;
    for (int tries = 0; tries < 32; ++tries) {
        const auto before = e->live_sequence.load();
        if (before & 1) continue;
        EGRankedRootsSnapshotV1 reading{};
        reading.size_bytes = sizeof(reading);
        reading.search_serial = e->live_serial.load();
        reading.count = e->live_rank_count.load();
        if (reading.count > EG_LIVE_RANKED_ROOTS_MAX) return 0;
        for (std::size_t i=0; i<EG_LIVE_RANKED_ROOTS_MAX; ++i)
            reading.moves[i] = e->live_rank_moves[i].load();
        const auto after = e->live_sequence.load();
        if (before == after && !(after & 1)) {
            *out = reading;
            return 1;
        }
    }
    return 0;
}

int eg_read_search_pv_v1(const EGEngine *e, EGSearchPVSnapshotV1 *out) {
    if (!e || !out || out->size_bytes != sizeof(EGSearchPVSnapshotV1))
        return 0;
    for (int tries = 0; tries < 32; ++tries) {
        const auto before = e->live_sequence.load();
        if (before & 1) continue;
        EGSearchPVSnapshotV1 reading{};
        reading.size_bytes = sizeof(reading);
        reading.search_serial = e->live_serial.load();
        reading.count = e->live_pv_count.load();
        reading.completed_depth = e->live_pv_depth.load();
        if (reading.count > EG_LIVE_PV_MAX) return 0;
        for (std::size_t i=0; i<EG_LIVE_PV_MAX; ++i)
            reading.moves[i] = e->live_pv_moves[i].load();
        const auto after = e->live_sequence.load();
        if (before == after && !(after & 1)) {
            *out = reading;
            return 1;
        }
    }
    return 0;
}

int eg_analyze_compute_policy_v2(
    EGEngine *e, const EGComputePolicyV2 *policy,
    const uint8_t *allowed, int32_t allowed_capacity,
    const int32_t *bonuses, int32_t bonus_capacity,
    EGComputeRunV2 *out) {
    if (!e || !policy || !out ||
        policy->size_bytes != sizeof(EGComputePolicyV2) ||
        out->size_bytes != sizeof(EGComputeRunV2) ||
        policy->reserved != 0 ||
        (policy->mode != EG_COMPUTE_MODE_ADAPTIVE &&
         policy->mode != EG_COMPUTE_MODE_BUDGETED) ||
        policy->max_wall_time_ms < 0 ||
        (policy->mode == EG_COMPUTE_MODE_ADAPTIVE && policy->max_wall_time_ms != 0) ||
        (policy->mode == EG_COMPUTE_MODE_BUDGETED && policy->max_wall_time_ms == 0) ||
        policy->max_depth < 1 || policy->max_depth > eclipse::kCells ||
        policy->root_width < 1 || policy->root_width > eclipse::kCells ||
        policy->reply_width < 1 || policy->reply_width > eclipse::kCells ||
        policy->continuation_width < 0 ||
        policy->continuation_width > eclipse::kCells ||
        policy->forced_line_depth < 0 ||
        policy->forced_line_depth > eclipse::kCells ||
        policy->candidate_radius < 1 ||
        policy->candidate_radius >= eclipse::kSide)
        return 0;
    if ((!allowed || !bonuses) ?
        (allowed != nullptr || bonuses != nullptr ||
         allowed_capacity != 0 || bonus_capacity != 0) :
        (allowed_capacity != eclipse::kCells ||
         bonus_capacity != eclipse::kCells))
        return 0;

    eclipse::RootPolicy root{};
    const eclipse::RootPolicy *root_pointer = nullptr;
    if (allowed && bonuses) {
        for (int i=0; i<eclipse::kCells; ++i) {
            if (allowed[i] > 1 || bonuses[i] < -2000 || bonuses[i] > 2000)
                return 0;
            root.allowed[i] = allowed[i] == 1;
            root.bonus[i] = bonuses[i];
        }
        root_pointer = &root;
    }

    eclipse::ComputePolicy chosen{};
    chosen.max_wall_time_ms = policy->max_wall_time_ms;
    chosen.max_nodes = policy->max_nodes;
    chosen.max_depth = policy->max_depth;
    chosen.root_width = policy->root_width;
    chosen.reply_width = policy->reply_width;
    chosen.continuation_width = policy->continuation_width;
    chosen.forced_line_depth = policy->forced_line_depth;
    chosen.candidate_radius = policy->candidate_radius;
    try {
        e->cancelled.store(false, std::memory_order_release);
        // Each VALID native execution gets a fresh serial. The engine is
        // never mutated concurrently except atomic cancellation or reads.
        e->live_sequence.fetch_add(1);
        e->live_serial.fetch_add(1);
        e->live_started_ns.store(steady_now_ns());
        e->live_nodes.store(0);
        e->live_depth.store(0);
        e->live_best.store(-1);
        e->live_reason.store(-1);
        e->live_elapsed_ms.store(0);
        e->live_rank_count.store(0);
        for (auto &index : e->live_rank_moves) index.store(-1);
        e->live_pv_count.store(0);
        e->live_pv_depth.store(0);
        for (auto &index : e->live_pv_moves) index.store(-1);
        e->live_state.store(EG_LIVE_SEARCH_RUNNING);
        e->live_sequence.fetch_add(1);
        const auto observer = [e](std::uint64_t nodes, int depth, int move) {
            publish_live(e, EG_LIVE_SEARCH_RUNNING, nodes, depth, move, -1, 0);
        };
        const auto root_observer = [e](const std::vector<int> &ranked) {
            publish_ranked(e, ranked);
        };
        const auto pv_observer = [e](int depth, const std::vector<int> &line) {
            publish_completed_pv(e, depth, line);
        };
        // No game history or training source escapes through this telemetry.
        const auto found = eclipse::Search{
            static_cast<eclipse::ResearchRanker>(e->research_ranker)}.analyze(
            e->board, 0, root_pointer, &chosen, &e->cancelled,
            observer, root_observer, pv_observer);
        if (found.reason == eclipse::SearchStopReason::cancelled ||
            (found.move < 0 && e->board.outcome == 0)) {
            publish_live(e, found.reason == eclipse::SearchStopReason::cancelled
                ? EG_LIVE_SEARCH_CANCELLED : EG_LIVE_SEARCH_FAILED,
                found.nodes, found.completed_depth, -1,
                static_cast<int32_t>(found.reason), found.elapsed_ms);
            return 0;
        }
        EGComputeRunV2 snapshot{};
        snapshot.size_bytes = sizeof(EGComputeRunV2);
        snapshot.search.size_bytes = sizeof(EGSearchDiagnosticsV1);
        snapshot.search.move = found.move;
        snapshot.search.completed_depth = found.completed_depth;
        snapshot.search.elapsed_ms = found.elapsed_ms;
        snapshot.search.nodes = found.nodes;
        snapshot.search.reason = static_cast<int32_t>(found.reason);
        snapshot.applied_policy = *policy; // exact caller-owned config echo
        *out = snapshot; // commit only on full success
        publish_live(e, EG_LIVE_SEARCH_COMPLETE, found.nodes,
                     found.completed_depth, found.move,
                     static_cast<int32_t>(found.reason), found.elapsed_ms);
        return 1;
    } catch (...) {
        // Never allow a C++ exception to cross the ABI boundary.
        publish_live(e, EG_LIVE_SEARCH_FAILED, e->live_nodes.load(),
                     e->live_depth.load(), -1, -1, 0);
        return 0;
    }
}
int eg_copy_board(const EGEngine *e,std::uint8_t *out225,int capacity){
    if(!e||!out225||capacity<eclipse::kCells)return -1;
    std::copy(e->board.cells.begin(),e->board.cells.end(),out225);
    return eclipse::kCells;
}
int eg_to_move(const EGEngine *e){return e?e->board.turn:0;}
int eg_status(const EGEngine *e){return e?e->board.outcome:-1;}
int eg_ply_count(const EGEngine *e){return e?static_cast<int>(e->board.moves.size()):-1;}
const char *eg_engine_revision(void){return "eclipse-cpp-prototype-v0.1-NOT-PARITY";}
}
