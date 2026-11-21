# VeilLink ECLIPSE UI integration

Source baseline: VeilLink `0e4b51e990ee1ab2c13c8b1b16bdb94ee8ee5f32`.

| Upstream component | Standalone wiring |
|---|---|
| `MiniGameViews.swift` Gomoku board and tap surface | Original geometry, colors, stones, winning line and tap handling. Adds VoiceOver grid controls. Omits the R17.2-excluded landing ripple. |
| `AppearanceTheme.swift`, `AppTheme.swift`, `SkeuomorphicComponents.swift` | Original day/night instrument palettes, plate, button and background. Keeps system/light/dark. Unrelated theme selection and messenger renderer overrides are excluded. |
| `VeilEclipseIdentityAndTrace.swift` | Original inline avatar and identity card open the original analysis and saved-match replay sheet. No separate lower instrumentation dashboard. |
| `VeilEclipseComputeConsole.swift`, `VeilEclipseConsoleStream.swift` | Original stream animation in the top card and the trace sheet. Stream is decorative. Game timing comes from the search start timestamp; last completed timing comes from the search result. |
| `VeilEclipseBoardThoughtField.swift` | Original branch reveal animation uses validated `onExploredLine` callbacks from active native search. The layer is opt-in, hidden outside the active scene, and displays static branches under Reduce Motion. |
| `VeilEclipseRuntimeInstruments.swift` | Frozen reference. Superseded by the owner's single-console R17.2 layout. |

Archived Swift sources remain byte-identical. The standalone versions can be compared directly with their originals under `Legacy/Original`. Simulation should cover dark/light, the trace toggle, a real AI turn, reopening a match, and replay playback. Physical device appearance and frame pacing remain separate acceptance checks.
