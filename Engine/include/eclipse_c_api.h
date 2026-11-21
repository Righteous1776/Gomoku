#ifndef ECLIPSE_C_API_H
#define ECLIPSE_C_API_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Experimental C++ search core. NOT a verified port of Swift ECLIPSE.
 * Versioned rules-replay ABI is stable and independently testable.
 * DO NOT use eg_best_move in the production Swift gameplay until tactical,
 * parity, search-strength, crash and 6x difficulty gates all pass.
 */
#define EG_RULES_ABI_VERSION 1
int eg_rules_abi_version(void);
/* Replay black-first moves onto a fresh 15x15 board. Rule set: freestyle,
 * five-or-more wins. No memory allocation crosses the C boundary.
 * Returns 1 only if all moves are legal and output arguments valid;
 * otherwise returns 0 and leaves ALL caller-provided outputs untouched.
 * Completion semantics intentionally match Swift GomokuState:
 * after a win/draw, to_move remains the player who placed the final stone.
 * Invalid input includes: negative/out-of-bounds count, null data with count>0,
 * duplicate move, a move made after a win, or short output capacity.
 * out225 always holds exactly 225 bytes; status: 0=ongoing,
 * 1=black won, 2=white won, 3=draw.
 */
int eg_rules_replay_v1(const int32_t *moves, int32_t count,
                       uint8_t *out225, int32_t capacity,
                       int32_t *out_to_move, int32_t *out_status);
typedef struct EGEngine EGEngine;

/* Freestyle Gomoku: 15x15, black=1 first, white=2, five or more wins. */
EGEngine *eg_create(void);
void eg_destroy(EGEngine *engine);
void eg_reset(EGEngine *engine);
int eg_play(EGEngine *engine, int index); /* 1 accepted; 0 rejected */
int eg_undo(EGEngine *engine); /* 1 undone; 0 no history */
int eg_best_move(const EGEngine *engine, int max_milliseconds); /* -1 on failure or finished */
int eg_copy_board(const EGEngine *engine, uint8_t *out225, int capacity); /* 225 on success */
int eg_to_move(const EGEngine *engine); /* 1 or 2 */
int eg_status(const EGEngine *engine); /* 0 ongoing, 1 black win, 2 white win, 3 draw */
int eg_ply_count(const EGEngine *engine);
const char *eg_engine_revision(void);

#ifdef __cplusplus
}
#endif
#endif
