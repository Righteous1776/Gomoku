# Original “拟物仪器” UI fidelity specification

## Source-of-truth

The appearance enum is `VeilAppearanceSelection.instrumentAuto` in `VeilLink/Core/AppearanceTheme.swift`. Reuse actual SwiftUI `VeilInstrumentBackground`, `VeilInstrumentPlate`, `VeilPhysicalButtonStyle`, `VeilIndicatorLamp`, `VeilSpeakerGrille`, `VeilLCDDisplay` and palette colors from original. Also review `SkeuomorphicPerformanceBudget.swift`, `VeilMotionKit.swift` and Game Lobby's `LocalAIGameView`.

## UI binding principles

- Fix theme selection to `instrumentAuto`; **do not** disable `.automatic/.light/.dark` color modes.
- Drop theme selectors for `veilOriginal`, `appleSoft`, `forge`, `plainline`, `islet` in independent app. Do NOT change original source app's theme.
- Keep original board material, grid spacing, star points, stone styling, animations, haptics and end-state indicators unless profiling establishes they cause a bug.
- Keep AI compute console and trace panels, but never let nonessential decorative gestures intercept `ScrollView` vertical drags, buttons or the board.
- Use native scrolling and smallest possible rendering invalidation while search runs. Ensure dynamic type, VoiceOver and safe-area behavior in both orientations supported by original game view.
- Record source screenshot vs new screenshot comparisons for dark/light, iPhone/iPad and after state transitions. No invented mockup substitutes for 1:1 source parity.

## Actual migration status (2026-11-21)

`InstrumentHomeView.swift` has been refactored from the original `VeilLink/UI/GameLobbyView.swift` LocalAIGameView hierarchy: compact state/metrics card, ECLIPSE identity/stream, seven-tier + full-depth controls, original board, then a single collapsible training & advanced panel. Independent Gomoku intentionally omits the parent VeilLink tab bar, messenger and unrelated games. `VeilEclipseRuntimeInstruments.swift` was copied unchanged from the original code and moved behind an explicit disclosure to prevent constant redraw and keep the board near the fold. The board retains original wood/grid/star/stone layout and has restored original post-move impact; it retains a stronger standalone accessibility implementation.

**This is SOURCE-ALIGNED, not 1:1 visual acceptance.** Xcode simulator screenshot capture and physical dark/light device comparisons have not executed on the current PR. Original `VeilLink` owner screenshots are the visual target, not independent app proof. Existing owner-provided photos were inspected but not stored in a public source directory. See `Docs/Operations/ECLIPSE_FULL_MIGRATION_ACCEPTANCE.md` for unresolved gates.

## Release UI check

- Original board view reused; original archive and learning controls present.
- No unrelated VeilLink messenger, Game Hall or profile chrome.
- No unnecessary theme options; day/night correct.
- Back from a game and reopen preserves state and scroll where applicable.
- No interaction hijacking from decorative effects; no noticeable freezes when AI computes.
