#!/usr/bin/env python3
"""Static package integrity and layout check, no network or platform dependencies."""
import json
from pathlib import Path
import subprocess

root=Path(__file__).resolve().parents[1]
required=['README.md','WORK_HANDOFF.md','project.yml','CMakeLists.txt','Engine/include/eclipse_c_api.h','Engine/src/board.cpp','Engine/src/search.cpp','Engine/src/eclipse_c_api.cpp','Engine/src/gomoku_cli.cpp','Training/validate_dataset.py','Training/selfplay.py','Training/train_policy.py','Migration/source_inventory.json','Scripts/migrate_from_veillink.py','Docs/QA/RELEASE_GATES.md','.github/workflows/cpp-python-ci.yml','.github/workflows/ios-build.yml','LICENSE']
missing=[f for f in required if not (root/f).is_file()]
assert not missing, f'missing: {missing}'
manifest=json.loads((root/'Migration/source_inventory.json').read_text())
assert manifest['upstream_commit'] and len(manifest['entries'])>40
assert len({i['path'] for i in manifest['entries']})==len(manifest['entries'])
print('package layout valid; staged source entries:',len(manifest['entries']))
