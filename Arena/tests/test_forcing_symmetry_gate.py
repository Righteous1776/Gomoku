"""Static synthetic fixture audit; no user data or engine executable required."""
import sys
from pathlib import Path
import unittest
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from forcing_symmetry_gate import BASE, fixtures, transformed


class SyntheticForcingFixtures(unittest.TestCase):
    def test_32_independent_transforms_but_four_pattern_families(self):
        cases = fixtures()
        self.assertEqual(len(cases), 32)
        self.assertEqual({x[0] for x in cases}, set(BASE))
        self.assertEqual(len({tuple(x[2]) for x in cases}), 32)
        for family, symmetry, history, certified in cases:
            self.assertEqual(symmetry in range(8), True)
            self.assertIn(transformed(112, symmetry), certified)
            for move, targets in certified.items():
                self.assertGreaterEqual(len(set(targets)), 2)
                self.assertNotIn(move, history)

    def test_each_dihedral_mapping_is_bijective(self):
        for symmetry in range(8):
            self.assertEqual(len({
                transformed(index, symmetry) for index in range(225)}), 225)


if __name__ == "__main__":
    unittest.main()
