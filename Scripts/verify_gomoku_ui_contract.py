#!/usr/bin/env python3
"""Fail-closed owner R17.2 UI source contract for standalone Gomoku.
Checks production source, NOT immutable Legacy/Original archives.
Source-pattern checks are not a substitute for Xcode + real-device QA.
"""
from pathlib import Path
import sys
ROOT=Path(__file__).resolve().parents[1]
APP=ROOT/"Apps/iOS/Gomoku"
home=(APP/"InstrumentHomeView.swift").read_text(encoding="utf-8")
bridge=(APP/"EngineBridge.swift").read_text(encoding="utf-8")
board=(APP/"BoardInstrumentView.swift").read_text(encoding="utf-8")
issues=[]
def need(condition, message):
    if not condition: issues.append(message)
need("VeilEclipseRuntimeInstruments(" not in home and "ECLIPSE / 实测仪表" not in home and "ENGINE STATUS" not in home,
     "rejected separate lower dashboard returned")
need("gomoku.eclipse.upper-compute-console" in home and "ECLIPSE / NATIVE INTELLIGENCE" in home,
     "real upper console missing")
need(all(token not in home+board for token in ("impactIndex","impactScale","impactExpanded")),
     "rejected move landing ripple returned")
need("REAL CLOCK  T+" in home and "timeIntervalSince(started)" in home,
     "honest elapsed search clock missing")
need("searchStartedAt = Date()" in bridge and "self.searchStartedAt = nil" in bridge,
     "clock not bound to real search state")
need("let selectedMove = answer" in bridge,
     "concurrency-safe immutable result not captured")
need("design: .rounded, weight:" not in home and "design: .monospaced, weight:" not in home,
     "SwiftUI font argument order regression")
need("BoardInstrumentView(" in home and "ForEach(0..<225" in board,
     "original standalone 15x15 board interaction lost")
if issues:
    for issue in issues: print("FAIL:",issue,file=sys.stderr)
    sys.exit(1)
print("GOMOKU OWNER R17.2 UI SOURCE CONTRACT PASS (8/8 static checks)")
