#include "board.hpp"
#include <algorithm>
#include <cmath>
#include <cstddef>

namespace eclipse {
namespace {
constexpr int kVectors[4][2] = {{1,0},{0,1},{1,1},{1,-1}};
constexpr bool in_range(int r,int c) {return r>=0&&r<kSide&&c>=0&&c<kSide;}
constexpr int other(int p) {return p==1?2:1;}
}

bool Board::legal(int index) const {
    return outcome==0 && index>=0 && index<kCells && cells[index]==0;
}

bool Board::five_at(int index,int player) const {
    if(index<0||index>=kCells||cells[index]!=player) return false;
    const int r=index/kSide, c=index%kSide;
    for(const auto &dir:kVectors) {
        int run=1;
        for(int sign:{-1,1}) {
            for(int n=1;n<kSide;++n) {
                int rr=r+sign*n*dir[0], cc=c+sign*n*dir[1];
                if(!in_range(rr,cc)||cells[rr*kSide+cc]!=player)break;
                ++run;
            }
        }
        if(run>=5)return true;
    }
    return false;
}

bool Board::winning_move(int index,int player) const {
    if(!legal(index)) return false;
    Board probe=*this;
    probe.cells[index]=static_cast<std::uint8_t>(player);
    return probe.five_at(index,player);
}

bool Board::play(int index) {
    if(!legal(index)) return false;
    const int player=turn;
    cells[index]=static_cast<std::uint8_t>(player);
    moves.push_back(index);
    if(five_at(index,player))outcome=player;
    else if(static_cast<int>(moves.size())==kCells)outcome=3;
    turn=other(player);
    return true;
}

bool Board::undo() {
    if(moves.empty())return false;
    int index=moves.back();moves.pop_back();
    cells[index]=0;
    turn=other(turn);
    outcome=0;
    return true;
}

void Board::reset() {cells.fill(0);turn=1;outcome=0;moves.clear();}

std::vector<int> Board::candidates(int radius) const {
    if(outcome!=0)return {};
    if(moves.empty())return {112};
    std::array<bool,kCells> marked{};
    std::vector<int> result;
    for(int i:moves) {
        int r=i/kSide,c=i%kSide;
        for(int dr=-radius;dr<=radius;++dr)
            for(int dc=-radius;dc<=radius;++dc) {
                const int rr=r+dr,cc=c+dc;
                if(!in_range(rr,cc))continue;
                const int idx=rr*kSide+cc;
                if(cells[idx]==0&&!marked[idx]) {marked[idx]=true;result.push_back(idx);}
            }
    }
    std::sort(result.begin(),result.end());
    return result;
}

std::int64_t Board::evaluate(int player) const {
    if(outcome==player)return 50'000'000;
    if(outcome==other(player))return -50'000'000;
    if(outcome==3)return 0;
    auto eval_side=[this](int p) -> std::int64_t {
        std::int64_t sum=0;
        for(int index=0;index<kCells;++index) {
            if(cells[index]!=p)continue;
            const int r=index/kSide,c=index%kSide;
            for(const auto &d:kVectors) {
                int prev_r=r-d[0],prev_c=c-d[1];
                if(in_range(prev_r,prev_c)&&cells[prev_r*kSide+prev_c]==p)continue;
                int length=0, rr=r,cc=c;
                while(in_range(rr,cc)&&cells[rr*kSide+cc]==p){++length;rr+=d[0];cc+=d[1];}
                int open=0;
                if(in_range(prev_r,prev_c)&&cells[prev_r*kSide+prev_c]==0)++open;
                if(in_range(rr,cc)&&cells[rr*kSide+cc]==0)++open;
                if(length>=5)sum+=25'000'000;
                else if(length==4)sum+=(open==2?400'000:open==1?80'000:0);
                else if(length==3)sum+=(open==2?15'000:open==1?3'000:0);
                else if(length==2)sum+=(open==2?600:open==1?80:0);
                else if(length==1)sum+=(open==2?8:2);
            }
        }
        return sum;
    };
    return eval_side(player)-eval_side(other(player))*11/10;
}
}
