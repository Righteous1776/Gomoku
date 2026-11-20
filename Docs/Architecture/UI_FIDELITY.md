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

## Existing package limitation

`Apps/iOS/Gomoku/InstrumentHomeView.swift` and `BoardInstrumentView.swift` are independently coded **temporary shell** components, visually thematic but NOT exact original UI components. Work must transplant and bind original UI before claiming completed migration.

## Release UI check

- Original board view reused; original archive and learning controls present.
- No unrelated VeilLink messenger, Game Hall or profile chrome.
- No unnecessary theme options; day/night correct.
- Back from a game and reopen preserves state and scroll where applicable.
- No interaction hijacking from decorative effects; no noticeable freezes when AI computes.
