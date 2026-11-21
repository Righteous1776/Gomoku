# Native Swift ECLIPSE default-engine candidate
This isolated feature branch changes `InstrumentHomeView` from `EngineBridge` (C++ experimental) to `NativeGomokuAppController`, using original `GomokuBot.chooseMove` with required tactical gates and seven tiers. No VeilLink app dependency.
C++ remains available as research, but is not the default in this proposed source.
At this stage learning passed as `.empty`, original persistent training, MatchArchive, trace and BLE are still unintegrated; therefore release and full parity remain blocked.
Do not merge to main until XCTest + original source and usability validation pass. No R17.2 lower dashboard/ripple is introduced. A legal fallback records a warning and invalidates strength benchmarking for that game.
