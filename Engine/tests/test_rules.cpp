#include "eclipse_c_api.h"
#include <array>
#include <stdexcept>
#define assert(expr) do { if(!(expr)) throw std::runtime_error("failed: " #expr); } while(false)
#include <iostream>
#include <memory>

int main(){
    std::unique_ptr<EGEngine,decltype(&eg_destroy)>e(eg_create(),eg_destroy);
    assert(e && eg_to_move(e.get())==1 && eg_ply_count(e.get())==0);
    EGSearchDiagnosticsV1 metrics{};
    metrics.size_bytes=sizeof(metrics);
    assert(eg_best_move_diagnostics_v1(e.get(),100,&metrics)==1);
    assert(metrics.move==112 && metrics.reason==EG_SEARCH_REASON_ONLY_MOVE);
    assert(metrics.nodes==0 && metrics.completed_depth==0 && metrics.elapsed_ms>=0);
    assert(metrics.reserved==0 && eg_ply_count(e.get())==0);
    EGSearchDiagnosticsV1 invalid=metrics;
    invalid.size_bytes=0;
    assert(eg_best_move_diagnostics_v1(e.get(),100,&invalid)==0);
    assert(invalid.move==112 && invalid.size_bytes==0);
    assert(eg_best_move_diagnostics_v1(nullptr,100,&metrics)==0);
    assert(metrics.move==112);
    assert(eg_best_move(e.get(),100)==112);
    assert(eg_play(e.get(),112)==1 && eg_play(e.get(),112)==0);
    assert(eg_undo(e.get())==1 && eg_ply_count(e.get())==0);
    assert(eg_undo(e.get())==0);
    eg_reset(e.get());
    for(int i=0;i<4;++i){assert(eg_play(e.get(),i)==1);assert(eg_play(e.get(),15+i)==1);}
    assert(eg_to_move(e.get())==1);
    metrics.size_bytes=sizeof(metrics);
    assert(eg_best_move_diagnostics_v1(e.get(),1,&metrics)==1);
    assert(metrics.move==4 && metrics.reason==EG_SEARCH_REASON_FORCED_WIN);
    assert(metrics.completed_depth==0 && eg_ply_count(e.get())==8);
    // R16: no 20-second clamp and trainer may request zero = open-ended.
    // Use an immediately provable win so the unlimited test terminates fast.
    EGSearchDiagnosticsV1 unlimited{};
    unlimited.size_bytes=sizeof(unlimited);
    assert(eg_best_move_diagnostics_v1(e.get(),0,&unlimited)==1);
    assert(unlimited.move==4 && unlimited.reason==EG_SEARCH_REASON_FORCED_WIN);
    assert(eg_best_move_diagnostics_v1(e.get(),120000,&unlimited)==1);
    assert(unlimited.move==4 && unlimited.reason==EG_SEARCH_REASON_FORCED_WIN);
    assert(eg_ply_count(e.get())==8);
    // Native Swift root learning may bias a legal alternative, but it must
    // NEVER override a certified immediate win. Invalid policies fail closed.
    std::array<std::uint8_t,225> allowed{};
    allowed.fill(1);
    std::array<std::int32_t,225> bonuses{};
    bonuses.fill(-2000);
    bonuses[9]=2000;
    EGSearchDiagnosticsV1 learned{};
    learned.size_bytes=sizeof(learned);
    assert(eg_best_move_root_policy_v1(e.get(),100,allowed.data(),225,
                                      bonuses.data(),225,&learned)==1);
    assert(learned.move==4 && learned.reason==EG_SEARCH_REASON_FORCED_WIN);
    assert(eg_ply_count(e.get())==8);
    allowed[4]=0;
    assert(eg_best_move_root_policy_v1(e.get(),100,allowed.data(),225,
                                      bonuses.data(),225,&learned)==0);
    assert(learned.move==4); // no partial overwrite on excluded mandatory win
    allowed[4]=1;
    bonuses[9]=2001;
    assert(eg_best_move_root_policy_v1(e.get(),100,allowed.data(),225,
                                      bonuses.data(),225,&learned)==0);
    assert(learned.move==4);
    bonuses[9]=2000;
    allowed[9]=2;
    assert(eg_best_move_root_policy_v1(e.get(),100,allowed.data(),225,
                                      bonuses.data(),225,&learned)==0);
    assert(learned.move==4);
    allowed[9]=1;
    assert(eg_best_move_root_policy_v1(e.get(),100,allowed.data(),224,
                                      bonuses.data(),225,&learned)==0);
    assert(learned.move==4);
    assert(eg_best_move(e.get(),100)==4); // immediate win
    assert(eg_play(e.get(),4)==1);
    assert(eg_status(e.get())==1);
    metrics.size_bytes=sizeof(metrics);
    assert(eg_best_move_diagnostics_v1(e.get(),1,&metrics)==1);
    assert(metrics.move==-1 && metrics.reason==EG_SEARCH_REASON_NO_MOVE);
    assert(eg_play(e.get(),40)==0);
    assert(eg_undo(e.get())==1 && eg_status(e.get())==0);
    eg_reset(e.get());
    // White threatens 4, while black has no four. Black must block 4.
    const int scattered[4] = {112,140,200,204};
    for(int i=0;i<4;++i){assert(eg_play(e.get(),scattered[i])==1);assert(eg_play(e.get(),i)==1);}
    assert(eg_best_move(e.get(),100)==4);
    metrics.size_bytes=sizeof(metrics);
    assert(eg_best_move_diagnostics_v1(e.get(),1,&metrics)==1);
    assert(metrics.move==4 && metrics.reason==EG_SEARCH_REASON_FORCED_BLOCK);
    assert(eg_ply_count(e.get())==8);
    eg_reset(e.get());
    // Swift R4/R8: placing 112 creates two DISTINCT future five-completions
    // (109 and 114), not simply two overlapping five-windows for one point.
    const int double_threat[6] = {110, 0, 111, 15, 113, 30};
    for (int index : double_threat) assert(eg_play(e.get(), index)==1);
    metrics.size_bytes=sizeof(metrics);
    assert(eg_best_move_diagnostics_v1(e.get(),250,&metrics)==1);
    assert(metrics.move==112 && metrics.reason==EG_SEARCH_REASON_FORCED_WIN);
    assert(eg_ply_count(e.get())==6); // analysis never changes board
    eg_reset(e.get());
    // Opponent's next move at 112 would fork two distinct winning squares.
    // The safe choices interrupt either the fork cell or one completion.
    const int white_fork[6] = {0, 110, 17, 111, 34, 113};
    for (int index : white_fork) assert(eg_play(e.get(), index)==1);
    const int fork_defense=eg_best_move(e.get(),300);
    assert(fork_defense==109 || fork_defense==112 || fork_defense==114);
    assert(eg_ply_count(e.get())==6);
    eg_reset(e.get());
    std::array<std::uint8_t,225> b{};
    assert(eg_copy_board(e.get(),b.data(),static_cast<int>(b.size()))==225);
    for(auto v:b)assert(v==0);
    assert(eg_copy_board(e.get(),b.data(),100)==-1);
    std::cout<<"C++ API and search smoke tests passed\n";
}
