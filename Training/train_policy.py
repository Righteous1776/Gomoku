"""Research-only imitation policy baseline, NOT bundled in the Gomoku app.
Requires PyTorch. Training data must have passed validate_dataset.validate_file.
Runtime inference and CoreML/ONNX conversion are separate validation gates.
"""
import argparse
import json
from pathlib import Path
import random
import sys

from validate_dataset import validate_file


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--dataset", type=Path, required=True)
    p.add_argument("--epochs", type=int, default=2)
    p.add_argument("--seed", type=int, default=42)
    p.add_argument("--out", type=Path, default=Path("Training/outputs/policy.pt"))
    o = p.parse_args()
    validate_file(o.dataset)
    try:
        import torch
        from torch import nn
    except ImportError as e:
        raise SystemExit("PyTorch unavailable. Install Training/requirements-train.txt") from e
    if o.epochs < 1:
        raise SystemExit("epochs must be positive")
    random.seed(o.seed)
    torch.manual_seed(o.seed)
    features, labels = [], []
    for line in o.dataset.open(encoding="utf-8"):
        if not line.strip():
            continue
        moves = json.loads(line)["moves"]
        board = [0] * 225
        for ply, mv in enumerate(moves):
            tensor = torch.zeros(3, 15, 15, dtype=torch.float32)
            for j, stone in enumerate(board):
                if stone:
                    tensor[stone - 1, j // 15, j % 15] = 1.0
            tensor[2].fill_(float(ply % 2 == 0))
            features.append(tensor)
            labels.append(mv)
            board[mv] = 1 + ply % 2
    if not features:
        raise SystemExit("no training samples")

    model = nn.Sequential(
        nn.Conv2d(3, 32, 3, padding=1), nn.ReLU(),
        nn.Conv2d(32, 64, 3, padding=1), nn.ReLU(),
        nn.Conv2d(64, 1, 1), nn.Flatten()
    )
    optim = torch.optim.AdamW(model.parameters(), lr=1e-3)
    x = torch.stack(features)
    y = torch.tensor(labels, dtype=torch.long)
    for epoch in range(o.epochs):
        order = torch.randperm(len(y))
        total = 0.0
        for batch in order.split(128):
            logits = model(x[batch])
            # Legal-square mask: disallow already-occupied squares in the target distribution.
            occupied = x[batch, 0].flatten(1).bool() | x[batch, 1].flatten(1).bool()
            logits = logits.masked_fill(occupied, -1e9)
            loss = nn.functional.cross_entropy(logits, y[batch])
            optim.zero_grad(); loss.backward(); optim.step()
            total += float(loss.item()) * len(batch)
        print(f"epoch {epoch+1}/{o.epochs}: training cross-entropy={total/len(y):.5f}")
    o.out.parent.mkdir(parents=True, exist_ok=True)
    torch.save({"state_dict": model.state_dict(), "seed": o.seed, "schema": "eclipse.policy.research.v1", "inputs": "3x15x15"}, o.out)
    o.out.with_suffix(o.out.suffix + ".json").write_text(json.dumps({"model": "simple-policy-research", "dataset": str(o.dataset), "trained_samples": len(y), "epochs": o.epochs, "runtime_integrated": False}, indent=2)+"\n")
    print(f"saved research checkpoint: {o.out}; not production verified")


if __name__ == "__main__":
    main()
