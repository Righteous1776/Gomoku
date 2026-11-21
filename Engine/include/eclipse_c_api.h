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

/* Additive, experimental telemetry ABI. Does NOT imply Swift parity.
 * Caller initializes size_bytes=sizeof(EGSearchDiagnosticsV1).
 * Returns 1 and replaces all fields on success; on failure returns 0 and
 * leaves the supplied output untouched. Does not mutate the game board.
 * Each invocation performs one search; do not call eg_best_move again just
 * to obtain the same move's diagnostics.
 */
#define EG_SEARCH_DIAGNOSTICS_ABI_VERSION 1
#define EG_SEARCH_REASON_COMPLETE 0
#define EG_SEARCH_REASON_FORCED_WIN 1
#define EG_SEARCH_REASON_FORCED_BLOCK 2
#define EG_SEARCH_REASON_ONLY_MOVE 3
#define EG_SEARCH_REASON_NO_MOVE 4
#define EG_SEARCH_REASON_TIME_LIMIT 5
typedef struct EGSearchDiagnosticsV1 {
    uint32_t size_bytes;
    int32_t move;            /* -1 for no legal move */
    int32_t completed_depth; /* fully finished iterative-deepening rounds */
    int32_t elapsed_ms;      /* observed wall-clock duration of this search */
    uint64_t nodes;          /* visited negamax nodes, excluding root preflight */
    int32_t reason;          /* EG_SEARCH_REASON_* */
    int32_t reserved;        /* must be 0 */
} EGSearchDiagnosticsV1;
int eg_best_move_diagnostics_v1(const EGEngine *engine, int max_milliseconds,
                                 EGSearchDiagnosticsV1 *out);

/* Research-only opt-in Swift formation/learning compatibility bridge.
 * allowed225[i] is 0 or 1; bonuses225[i] must be within [-2000, 2000].
 * Both arrays contain 225 entries, capacity MUST equal 225.
 * Caller must include compulsory win/block squares in allowed roots.
 * Invalid policy, no legal allowed move, or wrong diagnostics struct size
 * returns 0 without writing out. Tactical proofs outrank any bonuses.
 * Does not persist or reveal learning histories; inputs are caller-owned.
 * NOT production default until full Swift GomokuBot parity is certified.
 */
#define EG_ROOT_POLICY_ABI_VERSION 1
int eg_best_move_root_policy_v1(const EGEngine *engine, int max_milliseconds,
                                const uint8_t *allowed225, int allowed_capacity,
                                const int32_t *bonuses225, int bonus_capacity,
                                EGSearchDiagnosticsV1 *out);
/* R17: trainer-authoritative C++ V2 compute-policy ABI.
 * The distinct Training Agent supplies every search parameter. max_wall_time_ms
 * and max_nodes = 0 mean NO artificial deadline/node ceiling. Legacy V1
 * `eg_best_move` remains intact for historical Swift comparisons.
 *
 * IMPORTANT: an ABI policy is NOT an independently trained checkpoint.
 * The candidate remains RESEARCH-ONLY until checkpoint hash, runtime
 * identity and measured trained-Swift strength are independently verified.
 */
#define EG_COMPUTE_POLICY_ABI_VERSION 2
#define EG_COMPUTE_MODE_ADAPTIVE 0
#define EG_COMPUTE_MODE_BUDGETED 1
#define EG_SEARCH_REASON_CANCELLED 6
typedef struct EGComputePolicyV2 {
    uint32_t size_bytes;              /* must equal sizeof(EGComputePolicyV2) */
    uint32_t mode;                    /* ADAPTIVE with ms=0, BUDGETED with ms>0 */
    int64_t max_wall_time_ms;         /* 0=no time cutoff */
    uint64_t max_nodes;              /* 0=no node cap */
    int32_t max_depth;               /* 1..225 */
    int32_t root_width;              /* 1..225 */
    int32_t reply_width;             /* 1..225 */
    int32_t continuation_width;      /* 0..225; 0=reuse reply width */
    int32_t forced_line_depth;       /* 0..225 */
    int32_t candidate_radius;        /* 1..14 */
    uint32_t reserved;               /* must be 0 */
} EGComputePolicyV2;
typedef struct EGComputeRunV2 {
    uint32_t size_bytes;             /* must equal sizeof(EGComputeRunV2) */
    uint32_t reserved;               /* must be 0 */
    EGSearchDiagnosticsV1 search;    /* one actual search, never a rerun */
    EGComputePolicyV2 applied_policy;/* exact received parameter roundtrip */
} EGComputeRunV2;
int eg_compute_policy_abi_version(void);
/* If root constraints are unused pass both pointers NULL and both capacities 0.
 * To use learned Swift root constraints pass both arrays with capacities 225.
 * Mandatory win/block proof outranks root bonuses. Fails closed on bad sizes,
 * invalid geometry, illegal policies, cancelled searches, or no legal move.
 * On failure out remains ENTIRELY untouched. Board is never mutated.
 * Reentrant search on the SAME EGEngine is forbidden; one search per instance.
 */
int eg_analyze_compute_policy_v2(
    EGEngine *engine, const EGComputePolicyV2 *policy,
    const uint8_t *allowed225, int32_t allowed_capacity,
    const int32_t *bonuses225, int32_t bonus_capacity,
    EGComputeRunV2 *out);
/* The only concurrent-safe other operation during eg_analyze... is cancel.
 * The caller must NOT mutate/play/reset/destroy engine until search returns.
 */
void eg_cancel_search_v2(EGEngine *engine);

int eg_copy_board(const EGEngine *engine, uint8_t *out225, int capacity); /* 225 on success */
int eg_to_move(const EGEngine *engine); /* 1 or 2 */
int eg_status(const EGEngine *engine); /* 0 ongoing, 1 black win, 2 white win, 3 draw */
int eg_ply_count(const EGEngine *engine);
const char *eg_engine_revision(void);

#ifdef __cplusplus
}
#endif
#endif
