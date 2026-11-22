"""Exact R04/R07 research feature geometry, independent of private files.

F0..F25 follow the originally archived R04 `data_pipeline.features` logic.
F26..F33 follow the originally archived R07 `features34` logic.
All inputs are 15x15 freestyle boards (0 empty, 1 black, 2 white).
No user positions or personal archives are included here.
"""
from __future__ import annotations

import numpy as np

DIRECTIONS = ((1, 0), (0, 1), (1, 1), (1, -1))


def features26(board, index: int, side: int) -> np.ndarray:
    board = np.asarray(board, dtype=np.uint8)
    if board.shape != (225,):
        raise ValueError("expected flat 15x15 board")
    x = np.zeros(26, dtype=np.float32)
    if not 0 <= index < 225 or board[index] != 0 or side not in (1, 2):
        return x
    r, c = divmod(index, 15)
    enemy = 3 - side
    for dr, dc in DIRECTIONS:
        for offset in range(5):
            rr, cc = r - offset * dr, c - offset * dc
            if not (0 <= rr < 15 and 0 <= cc < 15 and
                    0 <= rr + 4 * dr < 15 and 0 <= cc + 4 * dc < 15):
                continue
            own = other = 0
            for k in range(5):
                val = board[(rr + k * dr) * 15 + cc + k * dc]
                own += int(val == side)
                other += int(val == enemy)
            if other == 0 and 1 <= own <= 4:
                x[own - 1] += 1
            if own == 0 and 1 <= other <= 4:
                x[4 + other - 1] += 1

    own_axes = enemy_axes = 0
    for dr, dc in DIRECTIONS:
        own = other = 1
        own_open = other_open = 0
        for sign in (-1, 1):
            rr, cc = r + sign * dr, c + sign * dc
            while 0 <= rr < 15 and 0 <= cc < 15 and board[rr * 15 + cc] == side:
                own += 1
                rr += sign * dr
                cc += sign * dc
            if 0 <= rr < 15 and 0 <= cc < 15 and board[rr * 15 + cc] == 0:
                own_open += 1
            rr, cc = r + sign * dr, c + sign * dc
            while 0 <= rr < 15 and 0 <= cc < 15 and board[rr * 15 + cc] == enemy:
                other += 1
                rr += sign * dr
                cc += sign * dc
            if 0 <= rr < 15 and 0 <= cc < 15 and board[rr * 15 + cc] == 0:
                other_open += 1
        x[8] = max(x[8], own)
        x[9] = max(x[9], other)
        if own >= 3 and own_open == 2:
            x[10] += 1
        if other >= 3 and other_open == 2:
            x[11] += 1
        if own >= 4 and own_open >= 1:
            x[12] += 1
        if other >= 4 and other_open >= 1:
            x[13] += 1
        if own >= 3 and own_open >= 1:
            own_axes += 1
        if other >= 3 and other_open >= 1:
            enemy_axes += 1
        for sign in (-1, 1):
            for distance in (1, 2):
                rr, cc = r + sign * distance * dr, c + sign * distance * dc
                if not 0 <= rr < 15 or not 0 <= cc < 15:
                    continue
                val = board[rr * 15 + cc]
                if val == side:
                    x[14 if distance == 1 else 16] += 1
                if val == enemy:
                    x[15 if distance == 1 else 17] += 1
    x[18] = 15 - abs(r - 7) - abs(c - 7)
    x[19] = min(r, c, 14 - r, 14 - c)
    x[20] = int(np.count_nonzero(board))
    x[21], x[22] = own_axes, enemy_axes
    x[23] = x[2] * (x[2] - 1) / 2
    x[24] = x[6] * (x[6] - 1) / 2
    x[25] = 1
    return x


def features34(board, index: int, side: int) -> np.ndarray:
    board = np.asarray(board, dtype=np.uint8)
    x = np.zeros(34, dtype=np.float32)
    x[:26] = features26(board, index, side)
    if not 0 <= index < 225 or board[index] != 0 or side not in (1, 2):
        return x
    r, c = divmod(index, 15)
    foe = 3 - side
    exact_win = must_block = own_three = own_four = enemy_three_block = 0
    holes: set[int] = set()
    for dr, dc in ((0, 1), (1, 0), (1, 1), (1, -1)):
        for offset in range(5):
            rr, cc = r - offset * dr, c - offset * dc
            if not (0 <= rr < 15 and 0 <= cc < 15 and
                    0 <= rr + 4 * dr < 15 and 0 <= cc + 4 * dc < 15):
                continue
            own = other = empty = 0
            last_empty = -1
            for t in range(5):
                loc = (rr + t * dr) * 15 + cc + t * dc
                val = side if loc == index else int(board[loc])
                if val == side:
                    own += 1
                elif val == foe:
                    other += 1
                else:
                    empty += 1
                    last_empty = loc
            if other == 0:
                if own == 5:
                    exact_win += 1
                if own == 4 and empty == 1:
                    own_four += 1
                    holes.add(last_empty)
                if own == 3 and empty == 2:
                    own_three += 1
            if own == 1 and other == 4:
                must_block += 1
            if own == 1 and other == 3 and empty == 1:
                enemy_three_block += 1
    x[26] = float(exact_win > 0)
    x[27] = float(must_block > 0)
    x[28] = len(holes)
    x[29] = enemy_three_block
    x[30] = float(len(holes) >= 2)
    x[31] = own_three
    x[32] = own_four
    x[33] = exact_win * 2 + must_block
    return x
