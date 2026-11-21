#!/usr/bin/env python3
"""Fail-closed V9 production provenance: full byte SHA and EXACT forest equivalence.

The compiled C++ .inc arrays MUST reproduce every split/leaf in the
corresponding immutable LightGBM source file, not merely share tree counts.
No private owner-game data is read or emitted.
"""
import hashlib
import math
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HANDOFF = ROOT / "Training/Handoffs/V9/source"
ARTIFACTS = (
    ("Astra", "astra-v9.lightgbm.txt", "astra_new.inc",
     "d50190d02bf6ebd6f447d84a2920184964ac9cff1dcc0712b0076cec326a177d", 314),
    ("Sol", "sol-v9.lightgbm.txt", "sol_new.inc",
     "074140fa99d52143ce3b887a553f1f11586973096baaada6476f97004e4b4fdd", 160),
)
NODE_RE = re.compile(r"\{(-?\d+),([^,{}]+),(-?\d+),(-?\d+),([^,{}]+)\}")
ROOT_RE = re.compile(r"roots\[\]=\{([^}]*)\}")


def fail(msg):
    raise AssertionError(msg)


def load_source(text):
    trees = []
    for part in re.split(r"(?=^Tree=\d+\s*$)", text, flags=re.MULTILINE)[1:]:
        entries = {}
        for line in part.splitlines():
            if "=" in line:
                key, value = line.split("=", 1)
                entries[key] = value
        if "num_leaves" not in entries:
            continue
        keys = ("split_feature", "threshold", "left_child",
                "right_child", "leaf_value")
        vals = {key: entries[key].split() for key in keys}
        n_leaves = int(entries["num_leaves"])
        n_internal = n_leaves - 1
        assert len(vals["split_feature"]) == n_internal
        assert len(vals["threshold"]) == n_internal
        assert len(vals["left_child"]) == n_internal
        assert len(vals["right_child"]) == n_internal
        assert len(vals["leaf_value"]) == n_leaves
        trees.append(vals)
    return trees


def expected_nodes(source_trees):
    all_nodes = []
    roots = []
    for tree in source_trees:
        roots.append(len(all_nodes))
        def walk(local):
            here = len(all_nodes)
            all_nodes.append(None)
            if local < 0:
                leaf = -local-1
                all_nodes[here] = (-1, 0.0, -1, -1,
                                    float(tree["leaf_value"][leaf]))
            else:
                left = walk(int(tree["left_child"][local]))
                right = walk(int(tree["right_child"][local]))
                all_nodes[here] = (int(tree["split_feature"][local]),
                                  float(tree["threshold"][local]),
                                  left, right, 0.0)
            return here
        walk(0)
    return all_nodes, roots


def parse_cpp(text):
    nodes = [
        (int(f), float(th), int(l), int(r), float(value))
        for f, th, l, r, value in NODE_RE.findall(text)
    ]
    match = ROOT_RE.search(text)
    assert match, "missing compiled root array"
    roots = [int(s) for s in match.group(1).split(",") if s.strip()]
    return nodes, roots


def verify_one(name, model_filename, inc_filename, digest, trees):
    path = HANDOFF / "models" / model_filename
    binary = path.read_bytes()
    actual_sha = hashlib.sha256(binary).hexdigest()
    assert actual_sha == digest, f"{name}: LightGBM source SHA mismatch"
    source = load_source(binary.decode("utf8"))
    assert len(source) == trees, f"{name}: unexpected raw tree count"
    expected, roots = expected_nodes(source)
    compiled, compiled_roots = parse_cpp(
        (HANDOFF / "research_engine" / inc_filename).read_text()
    )
    assert roots == compiled_roots, f"{name}: C++ forest root mapping differs"
    assert len(expected) == len(compiled), f"{name}: C++ node count differs"
    for index, (a, b) in enumerate(zip(expected, compiled)):
        if a[:1] != b[:1] or a[2:4] != b[2:4]:
            fail(f"{name} node {index}: feature or children differ")
        if not math.isclose(a[1], b[1], rel_tol=0, abs_tol=0):
            fail(f"{name} node {index}: threshold differs")
        if not math.isclose(a[4], b[4], rel_tol=0, abs_tol=0):
            fail(f"{name} node {index}: leaf coefficient differs")
    print(f"VERIFIED {name}: original source SHA256={actual_sha}; "
          f"trees={len(roots)}, compiled nodes={len(compiled)}; "
          "all node coefficients and pointers exact")


if __name__ == "__main__":
    for artifact in ARTIFACTS:
        verify_one(*artifact)
    print("PASS: actual embedded Astra/Sol C++ forests match pinned "
          "full-byte LightGBM artifact SHAs")
