#include "eclipse_c_api.h"
#include "board.hpp"
#include "search.hpp"
#include <algorithm>
#include <atomic>
#include <limits>
#include <new>

struct EGEngine {
    eclipse::Board board;
    std::atomic<bool> cancelled{false};
};

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
void eg_reset(EGEngine *e){if(e)e->board.reset();}
int eg_play(EGEngine *e,int index){return e&&e->board.play(index)?1:0;}
int eg_undo(EGEngine *e){return e&&e->board.undo()?1:0;}
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
int eg_compute_policy_abi_version(void) { return EG_COMPUTE_POLICY_ABI_VERSION; }
void eg_cancel_search_v2(EGEngine *e) {
    if (e) e->cancelled.store(true, std::memory_order_release);
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
        // No game history or training source escapes through this telemetry.
        const auto found = eclipse::Search{}.analyze(
            e->board, 0, root_pointer, &chosen, &e->cancelled);
        if (found.reason == eclipse::SearchStopReason::cancelled ||
            (found.move < 0 && e->board.outcome == 0))
            return 0;
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
        return 1;
    } catch (...) {
        // Never allow a C++ exception to cross the ABI boundary.
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
