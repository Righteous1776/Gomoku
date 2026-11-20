#!/usr/bin/env python3
"""TenGate Lite structural checks. No privileges, network, patch execution or auto-merge."""
import argparse
import json
import re
import subprocess
from pathlib import Path

ACTIVE = {'WORKING', 'REVIEW', 'ACCEPTED', 'APPLIED', 'VERIFIED'}
STATES = ACTIVE | {'OPEN', 'MERGED', 'BLOCKED', 'REJECTED'}
ID = re.compile(r'[A-Za-z0-9][A-Za-z0-9_-]{0,63}\Z')
SHA = re.compile(r'[0-9a-f]{40}\Z')
FILES = {'TASK.json', 'REPORT.md', 'PATCH.diff'}


def need(ok, why):
    if not ok:
        raise ValueError(why)


def git(repo, *args, data=None):
    p = subprocess.run(['git', '-C', str(repo), *args], input=data, capture_output=True)
    need(p.returncode == 0, p.stderr.decode(errors='replace') or 'git failed')
    return p.stdout


def safe(path):
    need(isinstance(path, str) and path and not path.startswith('/'), 'unsafe path')
    need(not any(c in path for c in '\\:*?[]\x00'), 'unsafe path character')
    need(all(p not in ('', '.', '..', '.git') for p in path.rstrip('/').split('/')), 'unsafe path segment')
    return path


def covers(scope, path):
    return path.startswith(scope) if scope.endswith('/') else scope == path


def check_board(board):
    need(board.get('schema') == 'gomoku-inbox-v1', 'unknown board schema')
    need(board.get('owner') == 'Righteous1776', 'unexpected owner')
    need(board.get('governor') is None or isinstance(board['governor'], str), 'bad governor')
    need(isinstance(board.get('tasks'), list), 'tasks must be a list')
    tasks = {}
    for t in board['tasks']:
        for k in ('task_id', 'agent_id'):
            need(isinstance(t.get(k), str) and ID.fullmatch(t[k]), 'invalid ' + k)
        need(t['task_id'] not in tasks, 'duplicate task')
        need(t.get('state') in STATES, 'unknown state')
        need(isinstance(t.get('scope'), list) and t['scope'], 'empty scope')
        for p in t['scope']:
            safe(p)
        for k in ('interfaces', 'depends_on'):
            need(isinstance(t.get(k), list) and all(isinstance(x, str) and x for x in t[k]), 'bad ' + k)
        need(t['state'] not in ACTIVE or t['agent_id'] != 'unassigned', 'active task needs assignee')
        tasks[t['task_id']] = t
    for t in tasks.values():
        need(all(d in tasks for d in t['depends_on']), 'missing dependency')
        if t['state'] in ACTIVE:
            need(all(tasks[d]['state'] == 'MERGED' for d in t['depends_on']), 'dependency not merged')
    def visit(key, trail):
        need(key not in trail, 'dependency cycle')
        for dep in tasks[key]['depends_on']:
            visit(dep, trail | {key})
    for key in tasks:
        visit(key, set())
    active = [t for t in tasks.values() if t['state'] in ACTIVE]
    for i, a in enumerate(active):
        for b in active[i + 1:]:
            need(not any(covers(x, y.rstrip('/')) or covers(y, x.rstrip('/')) for x in a['scope'] for y in b['scope']), 'active file conflict')
            need(not set(a['interfaces']) & set(b['interfaces']), 'active interface conflict')
    return tasks


def check_drop(repo, base, head, branch):
    need(SHA.fullmatch(base) and SHA.fullmatch(head), 'full SHAs required')
    need(git(repo, 'merge-base', base, head).decode().strip() == base, 'base not ancestor')
    parts = branch.split('/')
    need(len(parts) == 3 and parts[0] == 'agent-drop', 'bad drop branch')
    agent, task = parts[1:]
    need(ID.fullmatch(agent) and ID.fullmatch(task), 'bad IDs')
    def read(ref, path):
        return git(repo, 'show', ref + ':' + path).decode('utf-8')
    tasks = check_board(json.loads(read(base, 'AGENT_INBOX/BOARD.json')))
    need(task in tasks and tasks[task]['agent_id'] == agent, 'unassigned task')
    need(tasks[task]['state'] in {'WORKING', 'REVIEW'}, 'task not accepting drops')
    root = 'AGENT_INBOX/submissions/' + agent + '/' + task + '/'
    allowed = {root + f for f in FILES}
    changed = git(repo, 'diff', '--name-only', '--no-renames', '-z', base, head).decode().rstrip('\x00').split('\x00')
    need(changed != [''] and all(p in allowed for p in changed), 'shared/foreign path changed')
    need(not git(repo, 'ls-tree', '-r', '--name-only', base, root), 'existing submission immutable; use new task for revision')
    for row in git(repo, 'ls-tree', '-rz', head, root).split(b'\x00'):
        if row:
            mode, name = row.split(b'\t', 1)
            need(mode.startswith(b'100644 blob ') and name.decode() in allowed, 'unexpected file/mode')
    record = json.loads(read(head, root + 'TASK.json'))
    need(record.get('schema') == 'gomoku-drop-v1', 'unknown drop schema')
    need(record.get('agent_id') == agent and record.get('task_id') == task, 'identity mismatch')
    need(record.get('base_sha') == base, 'stale baseline')
    need(record.get('state') in {'DRAFT', 'REVIEW'}, 'worker cannot self-accept')
    need(isinstance(record.get('tests'), list) and record['tests'], 'test results or explicit NOT RUN required')
    for test in record['tests']:
        need(test.get('status') in {'PASS', 'FAIL', 'NOT RUN', 'BLOCKED'} and test.get('command') and test.get('evidence'), 'invalid test evidence')
    report = read(head, root + 'REPORT.md')
    for h in ('Goal', 'Changes', 'Risks', 'Rollback', 'Evidence', 'Next'):
        need('## ' + h in report, 'missing report section: ' + h)
    patch = read(head, root + 'PATCH.diff')
    if patch.startswith('NO_PATCH:'):
        need(patch[9:].strip(), 'NO_PATCH reason required')
        return {'state': 'VALIDATED_LOCAL', 'targets': []}
    need(not any(s in patch for s in ('GIT binary patch', 'Binary files ', 'rename from ', 'copy from ', '120000', '160000')), 'text-only patch required')
    targets = []
    for row in git(repo, 'apply', '--numstat', '-z', '-', data=patch.encode()).split(b'\x00'):
        if row:
            added, removed, path = row.decode().split('\t', 2)
            safe(path)
            need(added.isdigit() and removed.isdigit(), 'binary patch forbidden')
            need(not path.startswith('Legacy/Original/'), 'immutable snapshot: extraction requires separate owner-authorized integration')
            need(any(covers(s, path) for s in tasks[task]['scope']), 'patch outside scope')
            targets.append(path)
    need(targets, 'empty/malformed patch')
    return {'state': 'VALIDATED_LOCAL', 'targets': targets}


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--repo', type=Path, default=Path(__file__).resolve().parents[1])
    sub = p.add_subparsers(dest='cmd', required=True)
    sub.add_parser('status')
    sub.add_parser('check-board')
    drop = sub.add_parser('check-drop')
    for flag in ('base', 'head', 'branch'):
        drop.add_argument('--' + flag, required=True)
    a = p.parse_args()
    try:
        if a.cmd == 'check-drop':
            result = check_drop(a.repo, a.base, a.head, a.branch)
        else:
            board = json.loads((a.repo / 'AGENT_INBOX/BOARD.json').read_text())
            check_board(board)
            result = board if a.cmd == 'status' else {'state': 'BOARD_VALID'}
        print(json.dumps(result, ensure_ascii=False, indent=2))
    except (ValueError, OSError, KeyError, TypeError, UnicodeError) as error:
        p.exit(1, 'INBOX FAIL: ' + str(error) + '\n')


if __name__ == '__main__':
    main()
