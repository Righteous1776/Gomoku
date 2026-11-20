import importlib.util
import pathlib
import unittest

path = pathlib.Path(__file__).resolve().parents[1] / 'validate_dataset.py'
spec = importlib.util.spec_from_file_location('validate_dataset', path)
validation = importlib.util.module_from_spec(spec)
spec.loader.exec_module(validation)


class DatasetTests(unittest.TestCase):
    def test_five_horizontal(self):
        moves = [0, 15, 1, 16, 2, 17, 3, 18, 4]
        self.assertEqual(validation.replay(moves), 1)
        self.assertEqual(validation.validate_record({"schema": "eclipse.selfplay.v1", "rules": "freestyle-15", "winner": 1, "moves": moves}), 1)

    def test_illegal_duplicate(self):
        with self.assertRaises(ValueError):
            validation.replay([0, 15, 0])

    def test_truncated_unfinished(self):
        with self.assertRaises(ValueError):
            validation.replay([112])

    def test_false_winner(self):
        with self.assertRaises(ValueError):
            validation.validate_record({"schema": "eclipse.selfplay.v1", "rules": "freestyle-15", "winner": 2, "moves": [0,15,1,16,2,17,3,18,4]})


if __name__ == '__main__':
    unittest.main()
