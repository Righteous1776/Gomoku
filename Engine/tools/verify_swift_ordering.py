#!/usr/bin/env python3
"""Verify the frozen C++ R10 ordering constants equal the original Swift tokens.

This checks model provenance and *parameter values*. Independent feature/eval
behavior is tested by eclipse_r10_ordering_tests, not by this script.
"""
import re
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
SWIFT = ROOT / "Apps/iOS/Gomoku/NativeEclipse/EclipseTrainedOrdering.swift"
CPP = ROOT / "Engine/src/eclipse_trained_model_data.hpp"
SWIFT_NODE = re.compile(r"Node\(feature:\s*(-?\d+),\s*threshold:\s*([-+0-9.eE]+),\s*left:\s*(\d+),\s*right:\s*(\d+),\s*value:\s*([-+0-9.eE]+),\s*leaf:\s*(true|false)\)")
CPP_NODE = re.compile(r"^\s*\{(-?\d+), ([-+0-9.eE]+), (\d+), (\d+), ([-+0-9.eE]+), (true|false)\},\s*$", re.M)


def extract_roots(content, pattern):
    match = re.search(pattern, content)
    if match is None:
        raise ValueError("missing root list")
    return [int(p.strip()) for p in match.group(1).split(",")]


def verify():
    swift = SWIFT.read_text(encoding="utf-8")
    cpp = CPP.read_text(encoding="utf-8")
    source_sha = subprocess.check_output(
        ["git", "hash-object", str(SWIFT)], text=True).strip()
    if f"Source Git blob SHA: {source_sha}" not in cpp:
        raise ValueError("frozen model references an outdated Swift blob")
    roots_swift = extract_roots(swift, r"private static let roots:\s*\[Int\]\s*=\s*\[([^\]]+)\]")
    roots_cpp = extract_roots(cpp, r"inline constexpr int roots\[\]\s*=\s*\{([^}]+)\}")
    nodes_swift = SWIFT_NODE.findall(swift)
    nodes_cpp = CPP_NODE.findall(cpp)
    if len(roots_swift) != 48 or len(nodes_swift) != 1348:
        raise ValueError("Swift model shape changed; must review migration")
    if roots_swift != roots_cpp:
        raise ValueError("model roots differ")
    if nodes_swift != nodes_cpp:
        first = next((i for i, (a, b) in enumerate(zip(nodes_swift, nodes_cpp))
                      if a != b), min(len(nodes_swift), len(nodes_cpp)))
        raise ValueError(f"model node mismatch at index {first}")
    if "baseline = -48.060062448524974;" not in cpp:
        raise ValueError("model bias changed")
    if "output_multiplier = 12.0;" not in cpp:
        raise ValueError("model output multiplier changed")
    print(f"R10 frozen model token parity PASS: {len(roots_cpp)} roots, "
          f"{len(nodes_cpp)} nodes; source blob {source_sha}")


if __name__ == "__main__":
    verify()
