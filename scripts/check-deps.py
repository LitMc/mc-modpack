#!/usr/bin/env python3
"""Verify that all required Modrinth mod dependencies are present in mods-config.yaml."""

from __future__ import annotations

import sys
from pathlib import Path

import requests
import yaml

MODRINTH_API = "https://api.modrinth.com/v2"
REPO_ROOT = Path(__file__).resolve().parent.parent
CONFIG_PATH = REPO_ROOT / "mods-config.yaml"


def get_mod_dependencies(project_id: str, version_id: str) -> list[dict]:
    """Get dependencies for a specific mod version."""
    resp = requests.get(
        f"{MODRINTH_API}/version/{version_id}",
        timeout=30,
    )
    resp.raise_for_status()
    return resp.json().get("dependencies", [])


def get_project_slug(project_id: str) -> str:
    """Get human-readable slug for a project ID."""
    try:
        resp = requests.get(f"{MODRINTH_API}/project/{project_id}", timeout=30)
        resp.raise_for_status()
        data = resp.json()
        return data.get("slug", project_id)
    except Exception:
        return project_id


def main() -> int:
    with open(CONFIG_PATH) as f:
        config = yaml.safe_load(f)

    mods = config["mods"]
    known_project_ids = {m["modrinth_project_id"] for m in mods}

    print(f"Checking dependencies for {len(mods)} mods...")
    missing: list[tuple[str, str]] = []  # (mod_name, missing_dep_project_id)

    for mod in mods:
        name = mod["name"]
        project_id = mod["modrinth_project_id"]
        version_id = mod["modrinth_version_id"]

        deps = get_mod_dependencies(project_id, version_id)
        required_deps = [d for d in deps if d.get("dependency_type") == "required"]

        for dep in required_deps:
            dep_project_id = dep.get("project_id")
            if dep_project_id and dep_project_id not in known_project_ids:
                slug = get_project_slug(dep_project_id)
                print(f"  MISSING: {name} requires {slug} ({dep_project_id})")
                missing.append((name, slug))
            else:
                print(f"  OK: {name} dep {dep.get('project_id', '?')} satisfied")

    if missing:
        print(f"\nFAIL: {len(missing)} required dependencies missing from mods-config.yaml:")
        for mod_name, dep_slug in missing:
            print(f"  - {mod_name} requires: {dep_slug}")
        print("\nAdd missing mods to mods-config.yaml and re-run.")
        return 1

    print("\nAll dependencies satisfied.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
