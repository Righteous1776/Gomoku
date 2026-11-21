"""Regression guards for the source-aligned Gomoku ECLIPSE UI policy."""
import importlib.util
from pathlib import Path
import unittest


spec = importlib.util.spec_from_file_location(
    "gomoku_ui_contract",
    Path(__file__).resolve().parents[1] / "verify_gomoku_ui_contract.py",
)
ui_contract = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ui_contract)


class ECLIPSEInstrumentContractTests(unittest.TestCase):
    def setUp(self):
        self.sources = ui_contract.read_sources()

    def test_current_instrument_contract(self):
        failures = [name for name, valid in
                    ui_contract.evaluate_sources(self.sources).items() if not valid]
        self.assertEqual(failures, [])

    def test_second_board_instrument_plate_is_forbidden(self):
        self.sources["home"] = self.sources["home"].replace(
            '.frame(maxWidth: .infinity)\n'
            '        .accessibilityIdentifier("gomoku.instrument.board")',
            '.veilCard()\n'
            '        .accessibilityIdentifier("gomoku.instrument.board")',
            1
        )
        checks = ui_contract.evaluate_sources(self.sources)
        self.assertFalse(checks["unframed board fills narrow screens"])

    def test_edge_hit_targets_are_not_sacrificed_for_extra_board_size(self):
        self.sources["board"] = self.sources["board"].replace(
            "let margin = side * 0.055", "let margin = 0", 1
        )
        checks = ui_contract.evaluate_sources(self.sources)
        self.assertFalse(checks["wood board retains safe edge taps"])

    def test_unfolded_runtime_gauge_is_rejected(self):
        self.sources["home"] = self.sources["home"].replace(
            "if showsInstruments {", "if true {", 1
        )
        checks = ui_contract.evaluate_sources(self.sources)
        self.assertFalse(checks["original runtime instrument stays folded"])

    def test_ungated_stone_impact_is_rejected(self):
        self.sources["board"] = self.sources["board"].replace(
            "!eclipseSessionID.isEmpty && !reduceMotion",
            "!eclipseSessionID.isEmpty", 1
        )
        checks = ui_contract.evaluate_sources(self.sources)
        self.assertFalse(
            checks["impact respects reduced motion and cannot intercept taps"]
        )

    def test_wide_ipad_cockpit_must_retain_responsive_breakpoint(self):
        self.sources["home"] = self.sources["home"].replace(
            "viewport.size.width >= 900", "viewport.size.width >= 9999", 1
        )
        checks = ui_contract.evaluate_sources(self.sources)
        self.assertFalse(
            checks["wide iPad cockpit and compact split-view fallback"]
        )

    def test_missing_instrument_theme_fails(self):
        self.sources["appearance"] = self.sources["appearance"].replace(
            "let selection: VeilAppearanceSelection = .instrumentAuto",
            "let selection: VeilAppearanceSelection = .appleSoft", 1
        )
        checks = ui_contract.evaluate_sources(self.sources)
        self.assertFalse(checks["fixed instrument theme"])


if __name__ == "__main__":
    unittest.main()
