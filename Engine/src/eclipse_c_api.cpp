#include "eclipse_c_api.h"
#include "board.hpp"
#include "search.hpp"
#include <algorithm>
#include <new>

struct EGEngine {eclipse::Board board;};

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
