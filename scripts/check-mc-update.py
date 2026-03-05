#!/usr/bin/env python3
"""Check for Minecraft version updates and create PRs in both repos atomically."""

from __future__ import annotations

import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

import requests
from ruamel.yaml import YAML

PAPER_API = "https://api.papermc.io/v2/projects/paper"
MODRINTH_API = "https://api.modrinth.com/v2"
FABRIC_META = "https://meta.fabricmc.net/v2/versions/loader"

# Cross-repo update target
OCI_REPO = "LitMc/mc-server"
OCI_SETUP_SH = "scripts/setup.sh"
# Matches: MINECRAFT_VERSION="${MINECRAFT_VERSION:-X.XX.X}"
OCI_VERSION_RE = re.compile(
    r'(MINECRAFT_VERSION="\$\{MINECRAFT_VERSION:-)[^}]+(}")'
)

REPO_ROOT = Path(__file__).resolve().parent.parent
CONFIG_PATH = REPO_ROOT / "mods-config.yaml"

STABLE_VERSION_RE = re.compile(r"^\d+\.\d+(\.\d+)?$")


def get_mod_dependencies(version_id: str) -> list[dict]:
    """Get dependencies for a specific mod version."""
    resp = requests.get(f"{MODRINTH_API}/version/{version_id}", timeout=30)
    resp.raise_for_status()
    return resp.json().get("dependencies", [])


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


def run_git(*args: str, cwd: Path | None = None) -> str:
    result = subprocess.run(
        ["git", *args],
        cwd=cwd or REPO_ROOT,
        capture_output=True,
        text=True,
        check=True,
    )
    return result.stdout.strip()


def run_gh(*args: str, cwd: Path | None = None) -> str:
    result = subprocess.run(
        ["gh", *args],
        cwd=cwd or REPO_ROOT,
        capture_output=True,
        text=True,
        check=True,
    )
    return result.stdout.strip()


def delete_branch(branch: str, cwd: Path | None = None) -> None:
    """Delete a local and remote branch (best effort, for rollback)."""
    try:
        run_git("push", "origin", "--delete", branch, cwd=cwd)
        print(f"[rollback] Deleted remote branch {branch}")
    except Exception as e:
        print(f"[rollback] Could not delete remote branch {branch}: {e}")
    try:
        run_git("branch", "-D", branch, cwd=cwd)
        print(f"[rollback] Deleted local branch {branch}")
    except Exception:
        pass


def create_oci_pr(pat: str, new_version: str, current_version: str, branch: str) -> str:
    """
    Clone mc-server, update setup.sh, push branch, create PR.
    Returns the PR URL.
    """
    with tempfile.TemporaryDirectory() as tmpdir:
        tmp = Path(tmpdir)
        clone_url = f"https://x-access-token:{pat}@github.com/{OCI_REPO}.git"
        subprocess.run(
            ["git", "clone", "--depth=1", clone_url, str(tmp)],
            check=True,
            capture_output=True,
        )

        setup_sh = tmp / OCI_SETUP_SH
        content = setup_sh.read_text()
        new_content = OCI_VERSION_RE.sub(
            rf'\g<1>{new_version}\g<2>',
            content,
        )
        if new_content == content:
            raise RuntimeError(
                f"Could not find MINECRAFT_VERSION pattern in {OCI_SETUP_SH}"
            )
        setup_sh.write_text(new_content)

        # Configure git user for the commit
        subprocess.run(
            ["git", "config", "user.email", "github-actions@github.com"],
            cwd=tmp, check=True, capture_output=True,
        )
        subprocess.run(
            ["git", "config", "user.name", "github-actions"],
            cwd=tmp, check=True, capture_output=True,
        )

        subprocess.run(
            ["git", "checkout", "-b", branch],
            cwd=tmp, check=True, capture_output=True,
        )
        subprocess.run(
            ["git", "add", OCI_SETUP_SH],
            cwd=tmp, check=True, capture_output=True,
        )
        subprocess.run(
            ["git", "commit", "-m", f"feat: update Minecraft to {new_version}"],
            cwd=tmp, check=True, capture_output=True,
        )
        subprocess.run(
            ["git", "push", "-u", "origin", branch],
            cwd=tmp, check=True, capture_output=True,
        )

        # Create PR via gh (uses GH_TOKEN env = PAT)
        env = {**os.environ, "GH_TOKEN": pat}
        result = subprocess.run(
            [
                "gh", "pr", "create",
                "--repo", OCI_REPO,
                "--title", f"Update Minecraft to {new_version}",
                "--body", (
                    f"Automated server update: Minecraft {current_version} -> {new_version}\n\n"
                    f"This PR is part of an atomic update paired with mc-modpack."
                ),
                "--head", branch,
            ],
            cwd=tmp, check=True, capture_output=True, text=True, env=env,
        )
        return result.stdout.strip()


def delete_oci_branch(pat: str, branch: str) -> None:
    """Delete remote branch in OCI repo for rollback."""
    try:
        env = {**os.environ, "GH_TOKEN": pat}
        subprocess.run(
            ["gh", "api", "--method", "DELETE",
             f"/repos/{OCI_REPO}/git/refs/heads/{branch}"],
            check=True, capture_output=True, env=env,
        )
        print(f"[rollback] Deleted OCI remote branch {branch}")
    except Exception as e:
        print(f"[rollback] Could not delete OCI branch {branch}: {e}")


def main() -> int:
    dry_run = os.environ.get("DRY_RUN") == "1"
    gh_pat = os.environ.get("GH_PAT", "")

    yaml = YAML()
    yaml.preserve_quotes = True
    config = yaml.load(CONFIG_PATH)

    current_version = config["minecraft_version"]
    print(f"Current MC version: {current_version}")

    # latest_paper = MC version that Paper server supports (e.g. "1.21.11")
    latest_paper = get_latest_stable_mc_version()
    if not latest_paper:
        print("Could not determine latest stable MC version.")
        return 1

    print(f"Latest Paper-compatible MC version: {latest_paper}")

    # Check Modrinth App support — newly released MC versions may not be
    # in Modrinth's game version manifest yet, causing wrong version resolution.
    modrinth_versions = get_modrinth_supported_versions()
    if latest_paper not in modrinth_versions:
        msg = (
            f"MC {latest_paper} is available on Paper but not yet recognized by "
            f"Modrinth App. Update skipped until Modrinth adds support."
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

    # Check that all required dependencies are present for new version
    known_ids = {mod["modrinth_project_id"] for mod in config["mods"]}
    missing_deps: list[str] = []
    for i, mod in enumerate(config["mods"]):
        new_version_id = mod_updates.get(i, {}).get("modrinth_version_id") or mod["modrinth_version_id"]
        deps = get_mod_dependencies(new_version_id)
        for dep in deps:
            if dep.get("dependency_type") == "required":
                dep_id = dep.get("project_id")
                if dep_id and dep_id not in known_ids:
                    missing_deps.append(f"{mod['name']} -> {dep_id}")
    if missing_deps:
        msg = (
            f"MC {latest} update blocked: new required dependencies not in config: "
            + ", ".join(missing_deps)
        )
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
        print("[dry-run] Would update mods-config.yaml and mc-server (skipping).")
        if not gh_pat:
            print("[dry-run] WARNING: GH_PAT is not set. Cross-repo update would be skipped.")
        return 0

    yaml.dump(config, CONFIG_PATH)
    print("mods-config.yaml updated.")

    branch = f"auto-update/mc-{latest}"

    # Step 1: Create mc-modpack branch and commit
    run_git("checkout", "-b", branch)
    run_git("add", "mods-config.yaml")
    run_git("commit", "-m", f"feat: update Minecraft to {latest}")
    run_git("push", "-u", "origin", branch)
    print(f"mc-modpack: pushed branch {branch}")

    # Step 2: Create mc-server branch and commit (requires PAT)
    oci_pr_url = ""
    if gh_pat:
        try:
            oci_pr_url = create_oci_pr(gh_pat, latest, current_version, branch)
            print(f"mc-server PR created: {oci_pr_url}")
        except Exception as e:
            print(f"ERROR: mc-server update failed: {e}")
            print("Rolling back mc-modpack branch...")
            delete_branch(branch)
            send_ntfy(
                f"MC {latest} auto-update FAILED (cross-repo error). Manual update required."
            )
            return 1
    else:
        print("WARNING: GH_PAT not set. mc-server update skipped.")
        print("Set GH_PAT secret to enable atomic cross-repo updates.")

    # Step 3: Create mc-modpack PR
    pr_body = (
        f"Automated update: Minecraft {current_version} -> {latest}\n\n"
        f"All {len(config['mods'])} mods verified compatible.\n"
    )
    if oci_pr_url:
        pr_body += f"\nPaired server update PR: {oci_pr_url}"

    result = subprocess.run(
        [
            "gh", "pr", "create",
            "--title", f"Update Minecraft to {latest}",
            "--body", pr_body,
        ],
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
        check=True,
    )
    modpack_pr_url = result.stdout.strip()
    print(f"mc-modpack PR created: {modpack_pr_url}")

    msg = f"MC {latest} update PRs created. modpack: {modpack_pr_url}"
    if oci_pr_url:
        msg += f" | server: {oci_pr_url}"
    send_ntfy(msg)

    return 0


if __name__ == "__main__":
    sys.exit(main())
