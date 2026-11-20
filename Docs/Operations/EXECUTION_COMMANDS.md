# Deterministic execution commands for ChatGPT Work

## C++ and training

```sh
cmake -S . -B build -DCMAKE_BUILD_TYPE=Debug
cmake --build build --parallel
ctest --test-dir build --output-on-failure
python3 -m unittest discover -s Training/tests -v
python3 Scripts/verify_package.py
./build/Engine/gomoku_cli --best 112 --ms 30
python3 Training/selfplay.py --engine build/Engine/gomoku_cli --games 2 --ms 5 --seed 42 --out Training/outputs/selfplay.jsonl
python3 Training/validate_dataset.py --path Training/outputs/selfplay.jsonl
python3 Arena/compare.py --a build/Engine/gomoku_cli --b build/Engine/gomoku_cli --pairs 1 --ms 5
```

Install optional PyTorch separately, only when available and allowed:

```sh
python3 -m venv .venv
. .venv/bin/activate
python3 -m pip install -r Training/requirements-train.txt
python3 Training/train_policy.py --dataset Training/outputs/selfplay.jsonl --epochs 2
```

## Stage original source

```sh
git clone https://github.com/Righteous1776/VeilLink.git /tmp/VeilLink-Gomoku-source
git -C /tmp/VeilLink-Gomoku-source checkout 0e4b51e990ee1ab2c13c8b1b16bdb94ee8ee5f32
python3 Scripts/migrate_from_veillink.py --source /tmp/VeilLink-Gomoku-source --execute
python3 Scripts/audit_migration.py
```

## Create independent private repo (after owner authorization, Work only)

```sh
# Inside package root, on fresh filesystem and with git author identity configured:
./Scripts/prepare_repo.sh
# With GitHub CLI authenticated to authorized account:
gh repo create Righteous1776/Gomoku --private --source . --remote origin --push
# Verify remote URL and new repo main SHA after creation.
```

Do **not** run gh commands if the repository already exists; inspect and reconcile it instead of overwriting. Do not attempt to delete or mutate original VeilLink.
