import importlib.util
import pathlib
import tempfile
import unittest
import zipfile

script = pathlib.Path(__file__).resolve().parents[2] / 'Migration' / 'package_user_data.py'
spec = importlib.util.spec_from_file_location('package_user_data', script)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

class MigrationPackageTests(unittest.TestCase):
    def test_create_verify_extract(self):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            inp = root/'input'; inp.mkdir()
            (inp/'adaptive-board-learning-gomoku-v2.json').write_text('{"test":true}')
            history = inp/'GomokuMatchHistoryV1'; history.mkdir()
            (history/'demo.json').write_text('{"moves":[]}')
            archive = root/'backup.zip'
            mod.make_package(inp, archive)
            report = mod.verify_package(archive)
            self.assertEqual(report['entries'], 2)
            output = root/'out'
            mod.extract_package(archive, output)
            self.assertEqual((output/'GomokuMatchHistoryV1'/'demo.json').read_text(), '{"moves":[]}')

    def test_reject_unrelated_chat_file(self):
        with tempfile.TemporaryDirectory() as directory:
            root=pathlib.Path(directory)
            (root/'chat.sqlite').write_bytes(b'private')
            with self.assertRaises(ValueError):
                mod.make_package(root, root.parent/'unsafe.zip')

    def test_reject_invalid_zip_payload(self):
        with tempfile.TemporaryDirectory() as directory:
            p=pathlib.Path(directory)/'bad.zip'
            with zipfile.ZipFile(p,'w') as z:
                z.writestr('payload/../chat.json','secret')
                z.writestr('manifest.json','{"schema":"gomoku.archive.container.v1","rules":"freestyle-15","entries":[{"name":"../chat.json","size":6,"sha256":"'+'0'*64+'"}]}')
            with self.assertRaises(ValueError):
                mod.verify_package(p)

if __name__=='__main__': unittest.main()
