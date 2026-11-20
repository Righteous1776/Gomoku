#include "eclipse_c_api.h"
#include <array>
#include <stdexcept>
#define assert(expr) do { if(!(expr)) throw std::runtime_error("failed: " #expr); } while(false)
#include <iostream>
#include <memory>

int main(){
    std::unique_ptr<EGEngine,decltype(&eg_destroy)>e(eg_create(),eg_destroy);
    assert(e && eg_to_move(e.get())==1 && eg_ply_count(e.get())==0);
    assert(eg_best_move(e.get(),100)==112);
    assert(eg_play(e.get(),112)==1 && eg_play(e.get(),112)==0);
    assert(eg_undo(e.get())==1 && eg_ply_count(e.get())==0);
    assert(eg_undo(e.get())==0);
    eg_reset(e.get());
    for(int i=0;i<4;++i){assert(eg_play(e.get(),i)==1);assert(eg_play(e.get(),15+i)==1);}
    assert(eg_to_move(e.get())==1);
    assert(eg_best_move(e.get(),100)==4); // immediate win
    assert(eg_play(e.get(),4)==1);
    assert(eg_status(e.get())==1);
    assert(eg_play(e.get(),40)==0);
    assert(eg_undo(e.get())==1 && eg_status(e.get())==0);
    eg_reset(e.get());
    // White threatens 4, while black has no four. Black must block 4.
    const int scattered[4] = {112,140,200,204};
    for(int i=0;i<4;++i){assert(eg_play(e.get(),scattered[i])==1);assert(eg_play(e.get(),i)==1);}
    assert(eg_best_move(e.get(),100)==4);
    eg_reset(e.get());
    std::array<std::uint8_t,225> b{};
    assert(eg_copy_board(e.get(),b.data(),static_cast<int>(b.size()))==225);
    for(auto v:b)assert(v==0);
    assert(eg_copy_board(e.get(),b.data(),100)==-1);
    std::cout<<"C++ API and search smoke tests passed\n";
}
