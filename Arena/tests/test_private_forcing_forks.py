"""Synthetic only. Never use any owner's exported histories in CI."""
import sqlite3
import sys
import tempfile
import hashlib
import json
from pathlib import Path
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from private_forcing_forks import (
    analyze, double_win_targets, exhaust_opponent_replies, verified_sources,
)


class ForcingForkTests(unittest.TestCase):
    def test_distinct_five_completions_and_all_opponent_replies(self):
        board = [0] * 225
        for square in (110, 111, 113):
            board[square] = 1
        before = board.copy()
        targets = double_win_targets(board, 1, 112)
        self.assertEqual(targets, [109, 114])
        self.assertGreater(exhaust_opponent_replies(board, 1, 112, targets), 200)
        self.assertEqual(board, before)

    def test_single_completion_is_not_duplicate_window_fork(self):
        board = [0] * 225
        for square in (110, 111, 112):
            board[square] = 1
        board[109] = 2
        self.assertIsNone(double_win_targets(board, 1, 113))
        self.assertEqual(board[113], 0)

    def test_enemy_immediate_winning_reply_invalidates_fork(self):
        board = [0] * 225
        for square in (110, 111, 113):
            board[square] = 1
        for square in (30, 31, 32, 33):
            board[square] = 2
        self.assertIsNone(double_win_targets(board, 1, 112))
        self.assertEqual(board[112], 0)

    def test_one_turn_win_is_not_relabelled_two_turn(self):
        board = [0] * 225
        for square in (110, 111, 112, 113):
            board[square] = 1
        self.assertIsNone(double_win_targets(board, 1, 114))

    def test_synthetic_source_trust_and_noninflating_snapshots(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "synthetic.sqlite"
            conn = sqlite3.connect(path)
            conn.executescript("""
                create table metadata(k text primary key, v text);
                create table sources(id integer primary key, integrity text);
                create table sequences(id text primary key, actions_json text);
                create table game_observations(
                    id integer primary key, source_id integer, sequence_id text,
                    result text, diagnostic text);
                insert into metadata values('data_policy', 'LOCAL_ONLY; synthetic');
                insert into sources values(1, 'historical_sha_pinned');
                insert into sources values(2, 'quarantine_unverified_canonicalization');
                insert into sources values(3, 'canonical_match');
            """)
            # A fully legal 9-move synthetic game in which black makes
            # a four-in-a-row, with two distinct fifth-stone completions.
            history = [110, 0, 111, 15, 113, 30, 112, 45, 109]
            tokens = [("a" if i % 2 == 0 else "h") + str(m)
                      for i, m in enumerate(history)]
            digest = hashlib.sha256("\0".join(tokens).encode()).hexdigest()
            conn.execute("insert into sequences values(?,?)",
                         (digest, json.dumps(tokens)))
            for source_id, copies in ((1, 2), (3, 4), (2, 20)):
                for _ in range(copies):
                    conn.execute("""insert into game_observations(
                        source_id, sequence_id, result, diagnostic)
                        values(?,?,?,?)""",
                                 (source_id, digest, "humanWon", "ok"))
            conn.commit()
            conn.close()
            games = list(verified_sources(path))
            self.assertEqual(len(games), 1)
            self.assertEqual(games[0][1], 4)  # max one source, no snapshot inflation
            self.assertEqual(games[0][2], 2)  # no quarantined source counted
            cases, report = analyze(path, max_positions=0)
            self.assertGreaterEqual(report["distinct_ordered_prefixes"], 2)
            self.assertFalse(report["noninferiority_to_original_swift_verified"])
            self.assertNotIn("private_cases", report)
            self.assertIsInstance(cases, list)


if __name__ == "__main__":
    unittest.main()
