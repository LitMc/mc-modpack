#!/usr/bin/env python3
"""Check for Minecraft version updates and create PR if all mods are compatible."""

from __future__ import annotations

import os
import re
import subprocess
import sys
from pathlib import Path

import requests
from ruamel.yaml import YAML

PAPER_API = "https://api.papermc.io/v2/projects/paper"
MODRINTH_API = "https://api.modrinth.com/v2"
FABRIC_META = "https://meta.fabricmc.net/v2/versions/loader"

REPO_ROOT = Path(__file__).resolve().parent.parent
CONFIG_PATH = REPO_ROOT / "mods-config.yaml"

STABLE_VERSION_RE = re.compile(r"^\d+\.\d+(\.\d+)?$")


def get_modrinth_supported_versions() -> set[str]:
    """Get set of MC versions that Modrinth App officially supports."""
    resp = requests.get(f"{MODRINTH_API}/tag/game_version", timeout=30)
    resp.raise_for_status()
    return {v["version"] for v in resp.json() if v.get("version_type") == "release"}


def get_latest_stable_mc_version() -> str | None:
    """Get latest stable MC version from Paper API (must have default-channel build)."""
    resp = requests.get(PAPER_API, timeout=30)
    resp.raise_for_status()
    versions = resp.json()["versions"]

    # Filter to stable version strings, check from newest to oldest
    stable = [v for v in versions if STABLE_VERSION_RE.match(v)]
    for version in reversed(stable):
        builds_url = f"{PAPER_API}/versions/{version}/builds"
        builds_resp = requests.get(builds_url, timeout=30)
        builds_resp.raise_for_status()
        builds = builds_resp.json().get("builds", [])
        if any(b.get("channel") == "default" for b in builds):
            return version
    return None


def parse_major(version: str) -> list[str]:
    """Return first two components of version for major comparison."""
    return version.split(".")[:2]


def is_major_update(current: str, latest: str) -> bool:
    return parse_major(current) != parse_major(latest)


def check_mod_compatibility(
    project_id: str, new_version: str
) -> list[dict]:
    """Check if a mod has Fabric versions for the given MC version."""
    params = {"loaders": '["fabric"]', "game_versions": f'["{new_version}"]'}
    resp = requests.get(
        f"{MODRINTH_API}/project/{project_id}/version",
        params=params,
        timeout=30,
    )
    resp.raise_for_status()
    return resp.json()


def get_fabric_loader_version(mc_version: str) -> str | None:
    """Get latest stable Fabric loader version for a given MC version."""
    resp = requests.get(f"{FABRIC_META}/{mc_version}", timeout=30)
    resp.raise_for_status()
    for entry in resp.json():
        if entry.get("loader", {}).get("stable", False):
            return entry["loader"]["version"]
    return None


def send_ntfy(message: str) -> None:
    topic = os.environ.get("NTFY_TOPIC")
    if not topic:
        print(f"[ntfy skip] {message}")
        return
    try:
        requests.post(
            f"https://ntfy.sh/{topic}",
            data=message.encode("utf-8"),
            timeout=10,
        )
        print(f"[ntfy sent] {message}")
    except Exception as e:
        print(f"[ntfy error] {e}")


def run_git(*args: str) -> str:
    result = subprocess.run(
        ["git", *args],
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
        check=True,
    )
    return result.stdout.strip()


def main() -> int:
    dry_run = os.environ.get("DRY_RUN") == "1"

    yaml = YAML()
    yaml.preserve_quotes = True
    config = yaml.load(CONFIG_PATH)

    current_version = config["minecraft_version"]
    print(f"Current MC version: {current_version}")

    # latest_paper = MC version that Paper server supports (e.g. "1.21.11")
    # latest_mrpack = MC version that Modrinth App recognizes (may lag behind)
    latest_paper = get_latest_stable_mc_version()
    if not latest_paper:
        print("Could not determine latest stable MC version.")
        return 1

    print(f"Latest Paper-compatible MC version: {latest_paper}")

    # Check Modrinth App support separately — newly released MC versions may not
    # be in Modrinth's game version manifest yet, causing wrong version resolution.
    modrinth_versions = get_modrinth_supported_versions()
    if latest_paper not in modrinth_versions:
        # Paper supports it, but Modrinth App doesn't recognize it yet.
        # Server can run it, but we cannot update the mrpack yet.
        msg = (
            f"MC {latest_paper} is available on Paper but not yet recognized by "
            f"Modrinth App. mrpack update skipped until Modrinth adds support."
        )
        print(msg)
        send_ntfy(msg)
        return 0

    latest = latest_paper

    if latest == current_version:
        print("No update available.")
        return 0

    # Major version check
    if is_major_update(current_version, latest):
        msg = f"MC {latest} (major) available. Manual update required."
        print(msg)
        send_ntfy(msg)
        return 0

    # Minor/patch — check all mods
    print(f"Minor/patch update: {current_version} -> {latest}")
    incompatible = []
    mod_updates: dict[int, dict] = {}

    for i, mod in enumerate(config["mods"]):
        name = mod["name"]
        project_id = mod["modrinth_project_id"]
        versions = check_mod_compatibility(project_id, latest)
        if not versions:
            incompatible.append(name)
            print(f"  {name}: NOT compatible with {latest}")
        else:
            # Pick the first (latest) compatible version
            v = versions[0]
            primary = v["files"][0]
            mod_updates[i] = {
                "modrinth_version_id": v["id"],
                "file": primary["filename"],
                "url": primary["url"],
            }
            print(f"  {name}: compatible ({v['id']})")

    if incompatible:
        names = ", ".join(incompatible)
        msg = f"MC {latest} available but {names} not compatible yet."
        print(msg)
        send_ntfy(msg)
        return 0

    # All mods compatible — update config
    print("All mods compatible. Updating mods-config.yaml...")

    fabric_loader = get_fabric_loader_version(latest)
    if not fabric_loader:
        print(f"Could not find stable Fabric loader for {latest}")
        return 1
    print(f"Fabric loader: {fabric_loader}")

    config["minecraft_version"] = latest
    config["fabric_loader_version"] = fabric_loader
    for i, updates in mod_updates.items():
        for key, val in updates.items():
            config["mods"][i][key] = val

    if dry_run:
        print("[dry-run] Would update mods-config.yaml (skipping write and git).")
        return 0

    yaml.dump(config, CONFIG_PATH)
    print("mods-config.yaml updated.")

    # Git operations
    branch = f"auto-update/mc-{latest}"
    run_git("checkout", "-b", branch)
    run_git("add", "mods-config.yaml")
    run_git("commit", "-m", f"feat: update Minecraft to {latest}")
    run_git("push", "-u", "origin", branch)

    # Create PR
    result = subprocess.run(
        [
            "gh",
            "pr",
            "create",
            "--title",
            f"Update Minecraft to {latest}",
            "--body",
            f"Automated update: Minecraft {current_version} -> {latest}\n\n"
            f"All {len(config['mods'])} mods verified compatible.",
        ],
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
        check=True,
    )
    pr_url = result.stdout.strip()
    print(f"PR created: {pr_url}")
    send_ntfy(f"MC {latest} available. PR created: {pr_url}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
