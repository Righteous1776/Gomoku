"""No private data in CI: synthetic SQLite schema and legal game trajectories."""
import hashlib
import json
from pathlib import Path
import sqlite3
import sys
import tempfile
import unittest

sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from private_tactical_regression import extract, immediate, sample


def fixture(path):
    c=sqlite3.connect(path)
    c.executescript("""
      create table metadata(k text primary key,v text);
      create table sources(id integer primary key,integrity text);
      create table sequences(id text primary key,actions_json text);
      create table game_observations(id integer primary key,source_id integer,
          sequence_id text,result text,diagnostic text);
      insert into metadata values('data_policy','LOCAL_ONLY; do not upload');
      insert into sources values(1,'historical_sha_pinned');
      insert into sources values(2,'quarantine_unverified_canonicalization');
      insert into sources values(3,'canonical_match');
    """)
    def add(actions,source,n=1,diagnostic="ok"):
        ident=hashlib.sha256("\0".join(actions).encode()).hexdigest()
        c.execute("insert or ignore into sequences values(?,?)",
                  (ident,json.dumps(actions)))
        for _ in range(n):
            c.execute("""insert into game_observations(source_id,sequence_id,
                     result,diagnostic) values(?,?,?,?)""",
                      (source,ident,"aiWon",diagnostic))
    first=["a0","h15","a1","h16","a2","h17","a3","h18","a4"]
    add(first,1,2)
    add(first,3,4)
    add(first,2,5)
    add(["a60","h75","a61","h76","a62","h77","a63","h78","a64"],2,8)
    add(["a90","h105","a91","h106","a92","h107","a93","h108","a94"],
        1,1,"result_no_board_five")
    c.commit()
    c.close()


class PrivateTacticalTests(unittest.TestCase):
    def test_trust_and_no_duplicate_snapshot_inflation(self):
        with tempfile.TemporaryDirectory() as folder:
            path=Path(folder)/"synthetic.sqlite"
            fixture(path)
            cases,stats=extract(path)
            self.assertEqual(stats["trusted_distinct_sequences"],1)
            self.assertEqual(stats["quarantined_only_sequences"],1)
            self.assertEqual(stats["rejected_trusted_diagnostics"],1)
            self.assertEqual(stats["unique_immediate_win"],1)
            self.assertTrue(all(60 not in c["history"] for c in cases))
            win=next(c for c in cases if c["kind"]=="immediate_win")
            self.assertEqual(win["allowed"],[4])
            self.assertEqual(win["max_repeat"],4)
            self.assertEqual(len(win["witnesses"]),1)
            self.assertEqual(len(sample(cases,48)),len(cases))

    def test_rejects_missing_evidence_schema(self):
        with tempfile.TemporaryDirectory() as folder:
            path=Path(folder)/"empty.sqlite"
            sqlite3.connect(path).close()
            with self.assertRaises(ValueError):
                extract(path)

    def test_five_geometry(self):
        board=[0]*225
        for i in (0,1,2,3):
            board[i]=1
        self.assertEqual(immediate(board,1),[4])
        self.assertEqual(immediate(board,2),[])


if __name__=="__main__":
    unittest.main()
