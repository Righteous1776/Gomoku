import copy
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('inbox', Path(__file__).resolve().parents[1] / 'inbox.py')
inbox = importlib.util.module_from_spec(spec)
spec.loader.exec_module(inbox)


def task(tid='A', agent='alpha', scope=None, state='WORKING', deps=None, interfaces=None):
    return dict(task_id=tid, agent_id=agent, scope=scope or ['Engine/'], state=state,
                depends_on=deps or [], interfaces=interfaces or [])


def board(tasks):
    return dict(schema='gomoku-inbox-v1', owner='Righteous1776', governor=None, tasks=tasks)


class BoardTests(unittest.TestCase):
    def test_disjoint_lanes(self):
        inbox.check_board(board([task(), task('B', 'beta', ['Training/'])]))

    def test_file_conflict(self):
        with self.assertRaisesRegex(ValueError, 'file conflict'):
            inbox.check_board(board([task(), task('B', 'beta', ['Engine/src/search.cpp'])]))

    def test_interface_conflict(self):
        with self.assertRaisesRegex(ValueError, 'interface conflict'):
            inbox.check_board(board([task(interfaces=['C-ABI']), task('B', 'beta', ['Training/'], interfaces=['C-ABI'])]))

    def test_dependency_not_merged(self):
        with self.assertRaisesRegex(ValueError, 'dependency not merged'):
            inbox.check_board(board([task(state='OPEN'), task('B', 'beta', ['Training/'], deps=['A'])]))

    def test_dependency_cycle(self):
        with self.assertRaisesRegex(ValueError, 'cycle'):
            inbox.check_board(board([task(state='OPEN', deps=['B']), task('B', 'beta', state='OPEN', deps=['A'])]))

    def test_unassigned_active(self):
        with self.assertRaisesRegex(ValueError, 'assignee'):
            inbox.check_board(board([task(agent='unassigned')]))

    def test_path_traversal(self):
        for path in ('../Engine/', '/etc/passwd', 'Engine//x', '.git/config', 'C:/secret', 'Engine/*.cpp'):
            with self.subTest(path=path), self.assertRaises(ValueError):
                inbox.safe(path)


class DropTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.repo = Path(self.temp.name)
        self.run_git('init', '-q')
        self.write('AGENT_INBOX/BOARD.json', json.dumps(board([task()])))
        self.write('Engine/a.cpp', 'old\n')
        self.base = self.commit()
        self.root = 'AGENT_INBOX/submissions/alpha/A/'
        self.record = dict(schema='gomoku-drop-v1', agent_id='alpha', task_id='A', base_sha=self.base,
                           state='REVIEW', tests=[dict(command='manual', status='NOT RUN', evidence='fixture')])
        self.write(self.root + 'REPORT.md', '\n'.join('## ' + x + '\nFixture' for x in ('Goal', 'Changes', 'Risks', 'Rollback', 'Evidence', 'Next')))
        self.write(self.root + 'PATCH.diff', 'NO_PATCH: research fixture\n')

    def run_git(self, *args):
        return subprocess.check_output(['git', '-C', str(self.repo), '-c', 'user.name=Test', '-c', 'user.email=test@example.invalid', *args], stderr=subprocess.STDOUT).decode().strip()

    def write(self, path, text):
        dest = self.repo / path
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_text(text)

    def commit(self):
        self.run_git('add', '.')
        self.run_git('commit', '-qm', 'fixture')
        return self.run_git('rev-parse', 'HEAD')

    def check(self):
        self.write(self.root + 'TASK.json', json.dumps(self.record))
        return inbox.check_drop(self.repo, self.base, self.commit(), 'agent-drop/alpha/A')

    def test_valid_research_drop(self):
        self.assertEqual(self.check()['state'], 'VALIDATED_LOCAL')

    def test_valid_text_patch(self):
        self.write(self.root + 'PATCH.diff', 'diff --git a/Engine/a.cpp b/Engine/a.cpp\n--- a/Engine/a.cpp\n+++ b/Engine/a.cpp\n@@ -1 +1 @@\n-old\n+new\n')
        self.assertEqual(self.check()['targets'], ['Engine/a.cpp'])

    def test_shared_tree_write(self):
        self.write('Engine/a.cpp', 'unauthorized\n')
        with self.assertRaisesRegex(ValueError, 'shared/foreign'):
            self.check()

    def test_stale_base(self):
        self.record['base_sha'] = 'a' * 40
        with self.assertRaisesRegex(ValueError, 'stale'):
            self.check()

    def test_self_accept(self):
        self.record['state'] = 'ACCEPTED'
        with self.assertRaisesRegex(ValueError, 'self-accept'):
            self.check()

    def test_head_cannot_grant_itself_scope(self):
        self.write('AGENT_INBOX/BOARD.json', json.dumps(board([task(scope=['Training/'])])))
        with self.assertRaisesRegex(ValueError, 'shared/foreign'):
            self.check()

    def test_patch_outside_scope(self):
        self.write(self.root + 'PATCH.diff', 'diff --git a/Training/x b/Training/x\n--- /dev/null\n+++ b/Training/x\n@@ -0,0 +1 @@\n+bad\n')
        with self.assertRaisesRegex(ValueError, 'outside scope'):
            self.check()

    def test_symlink_submission(self):
        target = self.repo / (self.root + 'REPORT.md')
        target.unlink()
        target.symlink_to('/etc/passwd')
        with self.assertRaisesRegex(ValueError, 'file/mode'):
            self.check()

    def test_missing_test_evidence(self):
        self.record['tests'] = []
        with self.assertRaisesRegex(ValueError, 'test results'):
            self.check()


if __name__ == '__main__':
    unittest.main()
