#!/usr/bin/env python3
"""R15 TRAINER HANDOFF GATE. The training Agent builds; integration verifies.

Only accepts private LOCAL metadata/checkpoint. Do not commit model files or
training histories to GitHub. A model name/version is NEVER granted by merely
increasing time budget. This gate never auto-promotes a production model.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess

HEX256 = re.compile(r"^[0-9a-f]{64}$")
FAMILIES = frozenset({"luna", "terra", "sol", "astra"})
NATIVE_BUDGETS = (130,260,520,950,1900,3800,5700)


def validate_metadata(manifest: dict) -> dict:
    """Fail closed; no private history, trajectories or weights in metadata."""
    if not isinstance(manifest,dict) or manifest.get("schema") != "eclipse.trainer.handoff.v1":
        raise ValueError("wrong trainer handoff schema")
    mandatory = {
        "schema", "training_revision", "family", "proposed_generation",
        "checkpoint_sha256", "checkpoint_format", "provenance_sha256",
        "privacy_policy", "repeated_tactics_preserved",
        "independent_verified_game_groups", "augmentation_excluded_from_game_count",
        "native_compute_budgets_ms"
    }
    if set(manifest) != mandatory:
        raise ValueError("missing or nonapproved handoff fields")
    revision = manifest["training_revision"]
    if not isinstance(revision,str) or not re.fullmatch(r"R[1-9][0-9]{0,4}",revision):
        raise ValueError("invalid training revision (e.g. R29)")
    family = manifest["family"]
    generation = manifest["proposed_generation"]
    if family not in FAMILIES:
        raise ValueError("unapproved model family")
    if not isinstance(generation,str) or not re.fullmatch(r"[1-9][0-9]?\.[0-9]{1,2}",generation):
        raise ValueError("invalid proposed model generation")
    if (not isinstance(manifest["checkpoint_sha256"],str)
            or not HEX256.fullmatch(manifest["checkpoint_sha256"])):
        raise ValueError("invalid checkpoint sha256")
    if (not isinstance(manifest["provenance_sha256"],str)
            or not HEX256.fullmatch(manifest["provenance_sha256"])):
        raise ValueError("missing source provenance digest")
    if manifest["privacy_policy"] != "LOCAL_ONLY":
        raise ValueError("all private learning records must remain local")
    if (manifest["repeated_tactics_preserved"] is not True
            or manifest["augmentation_excluded_from_game_count"] is not True):
        raise ValueError("repeat/augmentation evidence policy failed")
    games = manifest["independent_verified_game_groups"]
    if type(games) is not int or games < 1:
        raise ValueError("independent match groups require verification")
    if not isinstance(manifest["checkpoint_format"],str) or not re.fullmatch(
            r"[a-z][a-z0-9._+-]{2,40}",manifest["checkpoint_format"]):
        raise ValueError("invalid artifact format")
    if manifest["native_compute_budgets_ms"] != list(NATIVE_BUDGETS):
        raise ValueError("all original seven Swift budget gates are required")
    return {
        "training_revision":revision,
        "family":family,
        "proposed_generation":generation,
        "release_candidate_id":f"eclipse-{generation}-{family}",
        "independent_verified_game_groups":games,
        "metadata_schema_valid":True,
        "strength_noninferiority_verified":False,
        "production_promotion_authorized":False
    }


def artifact_sha256(file: Path) -> str:
    h=hashlib.sha256()
    with file.open("rb") as stream:
        while block:=stream.read(1048576):
            h.update(block)
    return h.hexdigest()


def check_runner_identity(binary: Path, manifest: dict) -> None:
    """Candidate MUST attest which checkpoint is actually LOADED at runtime."""
    process=subprocess.run([str(binary.resolve()),"--identity"],
                           capture_output=True, text=True, timeout=10)
    if process.returncode != 0:
        raise ValueError("candidate runtime has no checkpoint identity interface")
    try:
        obj=json.loads(process.stdout)
    except (json.JSONDecodeError,TypeError):
        raise ValueError("candidate runtime returned non-JSON identity") from None
    if (obj.get("schema") != "eclipse.loaded-checkpoint-identity.v1"
        or obj.get("training_revision") != manifest["training_revision"]
        or obj.get("family") != manifest["family"]
        or obj.get("checkpoint_sha256") != manifest["checkpoint_sha256"]):
        raise ValueError("running engine checkpoint does not match manifest")
    if obj.get("checkpoint_loaded") is not True:
        raise ValueError("declared checkpoint not actually loaded")


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest",type=Path,required=True)
    parser.add_argument("--checkpoint",type=Path,
                        help="actual LOCAL checkpoint; never publish")
    parser.add_argument("--runner",type=Path,
                        help="real candidate model CLI implementing --identity")
    parser.add_argument("--out",type=Path,
                        help="LOCAL aggregate metadata-only review result")
    args=parser.parse_args()
    if bool(args.checkpoint) != bool(args.runner):
        parser.error("real checkpoint and matching runner are both required")
    manifest=json.loads(args.manifest.read_text(encoding="utf-8"))
    result=validate_metadata(manifest)
    result["checkpoint_file_sha256_verified"]=False
    result["runtime_loaded_checkpoint_verified"]=False
    if args.checkpoint:
        if artifact_sha256(args.checkpoint) != manifest["checkpoint_sha256"]:
            raise ValueError("checkpoint file digest does not match training handoff")
        result["checkpoint_file_sha256_verified"]=True
        check_runner_identity(args.runner,manifest)
        result["runtime_loaded_checkpoint_verified"]=True
    result["promotion_blocked_pending_true_trained_swift_strength_and_device_gate"]=True
    body=json.dumps(result,indent=2,ensure_ascii=False)+"\n"
    if args.out:
        args.out.write_text(body,encoding="utf-8")
    print(body,end="")


if __name__=="__main__":
    main()
