#include "eclipse_c_api.h"
#include <array>
#include <cstdint>
#include <stdexcept>
#include <vector>
#include <iostream>

#define REQUIRE(test) do {if (!(test)) throw std::runtime_error("failed: " #test);} while(false)

namespace {
struct Snapshot {
    std::array<uint8_t,225> board{};
    int32_t turn=-1;
    int32_t status=-1;
};
Snapshot verify(const std::vector<int32_t>& history) {
    Snapshot output;
    REQUIRE(eg_rules_replay_v1(
        history.data(),static_cast<int32_t>(history.size()),
        output.board.data(),static_cast<int32_t>(output.board.size()),
        &output.turn,&output.status)==1);
    return output;
}
}
int main() {
    REQUIRE(eg_rules_abi_version()==1);
    const auto empty=verify({});
    REQUIRE(empty.turn==1 && empty.status==0);
    for(auto cell:empty.board)REQUIRE(cell==0);

    auto afterOne=verify({112});
    REQUIRE(afterOne.turn==2 && afterOne.status==0 && afterOne.board[112]==1);
    auto two=verify({112,113});
    REQUIRE(two.turn==1 && two.status==0 && two.board[113]==2);

    const std::vector<int32_t> blackWin={0,15,1,16,2,17,3,18,4};
    const auto black=verify(blackWin);
    REQUIRE(black.status==1 && black.turn==1 && black.board[4]==1);
    const std::vector<int32_t> whiteWin={15,0,30,1,45,2,60,3,100,4};
    const auto white=verify(whiteWin);
    REQUIRE(white.status==2 && white.turn==2 && white.board[4]==2);
    const std::vector<int32_t> diagonal={0,1,16,2,32,3,48,4,64};
    const auto diag=verify(diagonal);
    REQUIRE(diag.status==1 && diag.turn==1);

    // All outputs are caller-owned. Failed input must leave them untouched.
    auto board=afterOne.board;
    int32_t turn=77,status=88;
    std::array<uint8_t,225> copy=board;
    std::vector<int32_t> duplicate={112,112};
    REQUIRE(!eg_rules_replay_v1(duplicate.data(),2,board.data(),225,&turn,&status));
    REQUIRE(board==copy && turn==77 && status==88);
    auto beyond=blackWin;beyond.push_back(20);
    REQUIRE(!eg_rules_replay_v1(beyond.data(),static_cast<int32_t>(beyond.size()),
                                 board.data(),225,&turn,&status));
    REQUIRE(!eg_rules_replay_v1(nullptr,1,board.data(),225,&turn,&status));
    REQUIRE(!eg_rules_replay_v1(nullptr,-1,board.data(),225,&turn,&status));
    REQUIRE(!eg_rules_replay_v1(nullptr,226,board.data(),225,&turn,&status));
    REQUIRE(!eg_rules_replay_v1(blackWin.data(),9,board.data(),224,&turn,&status));
    REQUIRE(!eg_rules_replay_v1(blackWin.data(),9,nullptr,225,&turn,&status));
    REQUIRE(!eg_rules_replay_v1(blackWin.data(),9,board.data(),225,nullptr,&status));
    REQUIRE(!eg_rules_replay_v1(blackWin.data(),9,board.data(),225,&turn,nullptr));
    REQUIRE(board==copy && turn==77 && status==88);

    std::cout<<"Freestyle rule ABI v1 and Swift terminal-turn semantics PASS\n";
}
