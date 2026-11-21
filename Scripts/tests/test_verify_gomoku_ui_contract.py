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

    def test_runtime_instrument_cannot_be_hidden_or_reordered(self):
        self.sources["home"] = self.sources["home"].replace(
            "VeilEclipseRuntimeInstruments(",
            "if showsInstruments { VeilEclipseRuntimeInstruments(", 1
        )
        checks = ui_contract.evaluate_sources(self.sources)
        self.assertFalse(checks[
            "original VeilLink runtime instrument is visible between identity and controls"
        ])

    def test_veillink_layout_order_cannot_be_rearranged(self):
        self.sources["home"] = self.sources["home"].replace(
            "                    eclipseIdentity\n",
            "                    boardQuickControls\n                    eclipseIdentity\n",
            1
        )
        checks = ui_contract.evaluate_sources(self.sources)
        self.assertFalse(checks["source-aligned game hierarchy"])

    def test_veillink_identity_brand_is_pinned(self):
        self.sources["identity"] = self.sources["identity"].replace(
            'Text("VeilLink Native Intelligence")',
            'Text("Custom Cyber AI")', 1
        )
        checks = ui_contract.evaluate_sources(self.sources)
        self.assertFalse(checks[
            "VeilLink identity uses original copy and measured elapsed clock"
        ])

    def test_ungated_stone_impact_is_rejected(self):
        self.sources["board"] = self.sources["board"].replace(
            "!eclipseSessionID.isEmpty && !reduceMotion",
            "!eclipseSessionID.isEmpty", 1
        )
        checks = ui_contract.evaluate_sources(self.sources)
        self.assertFalse(
            checks["impact respects reduced motion and cannot intercept taps"]
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
