"""Synthetic-only integrity tests for Tianyuan 6x teacher / R07 distillation."""
from __future__ import annotations

import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "Arena"))
sys.path.insert(0, str(ROOT / "Training/research/r07"))
sys.path.insert(0, str(ROOT / "Training/research/r07/source"))

from zenith_teacher_dataset import (classify_teacher_trace, d4_family, five,
                                    nearby, replay, seeded_history, validate_pv)
from zenith_distillation import features34, split_family, make_groups


class TianyuanSourceContractTests(unittest.TestCase):
    def test_real_r04_and_r07_feature_fixture(self):
        # Values were computed from the ORIGINAL R04 data_pipeline.py and
        # ORIGINAL R07 features34.py from the locally archived research ZIP.
        sample = [
            ([112, 97, 111, 98], 113,
             [1,3,0,0,8,0,0,0,3,2,1,0,0,0,1,2,1,0,14,6,4,1,0,0,0,1,0,0,0,0,0,3,0,0]),
            ([110, 0, 111, 15, 113, 30], 112,
             [1,2,2,0,0,0,0,0,4,1,1,0,1,0,2,0,1,0,15,7,6,1,0,1,0,1,0,0,2,0,1,2,2,0]),
        ]
        for history, move, expected in sample:
            board = replay(history)
            result = features34(board, move, 1 + len(history) % 2)
            self.assertEqual(result.tolist(), expected)
            self.assertEqual(len(result), 34)

    def test_legal_board_and_pv(self):
        history = [112, 97, 111, 98]
        board = replay(history)
        self.assertEqual(len(board), 225)
        self.assertNotIn(112, nearby(board))
        self.assertIn(113, nearby(board))
        validate_pv(board, 1, [113, 114])
        with self.assertRaises(ValueError):
            validate_pv(board, 1, [112])
        with self.assertRaises(ValueError):
            replay([112, 112])

    def test_symmetry_compatible_split(self):
        seq = [112, 97, 111, 98]
        rot = [((i % 15) * 15 + 14 - i // 15) for i in seq]
        self.assertEqual(d4_family(seq), d4_family(rot))
        self.assertIn(split_family(d4_family(seq)), ("train", "validation"))

    def test_synthetic_histories_nonterminal_and_deterministic(self):
        for seed in range(20):
            a = seeded_history(20261122 + 7919 * seed)
            b = seeded_history(20261122 + 7919 * seed)
            self.assertEqual(a, b)
            replay(a)

    def test_forcing_proof_depth_is_not_iterative_search_depth(self):
        forced = [{"phase": "complete", "completed_depth": 10,
                   "rule": "verified-forcing-four"}]
        self.assertEqual(classify_teacher_trace(forced), (0, 10))
        ordinary = [
            {"phase": "deepening", "completed_depth": 5, "rule": "completed-depth"},
            {"phase": "complete", "completed_depth": 5, "rule": "iterative-pvs"},
        ]
        self.assertEqual(classify_teacher_trace(ordinary), (5, 0))
        with self.assertRaises(ValueError):
            classify_teacher_trace(forced + ordinary)

    def test_no_training_on_zero_depth_teacher(self):
        records = []
        for seed in range(12):
            history = seeded_history(20270000 + seed * 7919)
            board = replay(history)
            roots = nearby(board)
            move = roots[0]
            row = {"family": d4_family(history), "history": history,
                   "candidate_roots": roots, "teacher_move": move,
                   "to_move": 1 + len(history) % 2,
                   "teacher_depth": 0}
            records.append((row, board))
        grouped, excluded, families = make_groups(records)
        self.assertEqual(excluded, len(records))
        self.assertEqual(len(grouped["train"]) + len(grouped["validation"]), 0)
        self.assertGreater(len(families), 0)


if __name__ == "__main__":
    unittest.main()
