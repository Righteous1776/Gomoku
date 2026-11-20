#include "eclipse_c_api.h"
#include "board.hpp"
#include "search.hpp"
#include <algorithm>
#include <new>

struct EGEngine {eclipse::Board board;};

extern "C" {
EGEngine *eg_create(void){return new(std::nothrow) EGEngine{};}
void eg_destroy(EGEngine *e){delete e;}
void eg_reset(EGEngine *e){if(e)e->board.reset();}
int eg_play(EGEngine *e,int index){return e&&e->board.play(index)?1:0;}
int eg_undo(EGEngine *e){return e&&e->board.undo()?1:0;}
int eg_best_move(const EGEngine *e,int ms){if(!e)return -1;return eclipse::Search{}.best_move(e->board,ms);}
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
