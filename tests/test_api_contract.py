"""Contract tests against real external APIs.

These tests verify the response shape of the third-party APIs that
``scripts/check-mc-update.py`` depends on:

* PaperMC v3 (https://fill.papermc.io)
* Modrinth v2 (https://api.modrinth.com)
* Fabric Meta v2 (https://meta.fabricmc.net)

They are opt-in via ``-m contract`` and run on a daily GitHub Actions cron
so we detect breaking API changes early instead of letting the production
auto-update job fail silently (cmd_327 14-day regression).

Assertions focus on **presence, type, and value-domain** of keys the
production code reads. They deliberately avoid asserting exact values
(which legitimately drift day-to-day) to stay stable under normal
upstream churn.

The User-Agent header matches ``scripts/check-mc-update.py`` so Modrinth
(which 429s missing/anonymous UA) and PaperMC treat these probes the
same as the production job.

Session-scoped fixtures share HTTP responses across tests to keep the
external call count bounded (≤10 per run) and respect upstream rate
limits.
"""
from __future__ import annotations

import re

import pytest
import requests

PAPER_API = "https://fill.papermc.io/v3/projects/paper"
MODRINTH_API = "https://api.modrinth.com/v2"
FABRIC_META = "https://meta.fabricmc.net/v2/versions/loader"

USER_AGENT = "jln-hut-modpack/1.0 (https://github.com/LitMc/mc-modpack)"
HEADERS = {"User-Agent": USER_AGENT}
TIMEOUT = 10

SEMVER_RE = re.compile(r"^\d+\.\d+(\.\d+)?$")
ISO8601_RE = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}")

PAPER_CHANNELS = {"STABLE", "BETA", "ALPHA"}
MODRINTH_VERSION_TYPES = {"release", "snapshot", "alpha", "beta"}

# MC version to probe Fabric-per-version loader endpoint with. Picked as a
# long-stable release so the fixture URL does not 404 when the latest MC
# version is still missing from Fabric Meta.
FABRIC_PROBE_MC_VERSION = "1.21.1"


# ---------------------------------------------------------------------------
# Session-scoped HTTP fixtures (keep external call count ≤ 10)
# ---------------------------------------------------------------------------

@pytest.fixture(scope="session")
def paper_projects() -> dict:
    resp = requests.get(PAPER_API, headers=HEADERS, timeout=TIMEOUT)
    resp.raise_for_status()
    return resp.json()


@pytest.fixture(scope="session")
def paper_release_candidates(paper_projects) -> list[str]:
    """All release-format versions, newest-first (matches production order)."""
    candidates: list[str] = []
    for group_versions in paper_projects["versions"].values():
        candidates.extend(group_versions)
    release = [v for v in candidates if SEMVER_RE.match(v)]
    if not release:
        pytest.fail("Could not find any release-format versions to probe")
    return release


@pytest.fixture(scope="session")
def paper_builds_stable(paper_release_candidates) -> tuple[str, list]:
    """First (version, builds) pair where builds is a non-empty STABLE list.

    Mirrors ``get_latest_stable_mc_version``'s fallback behavior: the
    newest version frequently has no STABLE builds yet, so production
    walks down the candidates list. If we find no STABLE builds across
    the first handful of candidates the API is effectively broken for
    production, so we fail instead of skipping.
    """
    probe_limit = 5
    last_shape_seen: list | None = None
    for version in paper_release_candidates[:probe_limit]:
        resp = requests.get(
            f"{PAPER_API}/versions/{version}/builds",
            params={"channel": "STABLE"},
            headers=HEADERS,
            timeout=TIMEOUT,
        )
        resp.raise_for_status()
        builds = resp.json()
        last_shape_seen = builds
        if builds:
            return version, builds

    pytest.fail(
        f"No STABLE PaperMC builds found across the last {probe_limit} "
        f"release-format versions — production auto-update would fail. "
        f"Last response shape: {type(last_shape_seen).__name__}"
    )


@pytest.fixture(scope="session")
def modrinth_fabric_api_project() -> dict:
    resp = requests.get(
        f"{MODRINTH_API}/project/fabric-api",
        headers=HEADERS,
        timeout=TIMEOUT,
    )
    resp.raise_for_status()
    return resp.json()


@pytest.fixture(scope="session")
def modrinth_fabric_api_versions() -> list:
    resp = requests.get(
        f"{MODRINTH_API}/project/fabric-api/version",
        headers=HEADERS,
        timeout=TIMEOUT,
    )
    resp.raise_for_status()
    return resp.json()


@pytest.fixture(scope="session")
def fabric_loader_list() -> list:
    resp = requests.get(FABRIC_META, headers=HEADERS, timeout=TIMEOUT)
    resp.raise_for_status()
    return resp.json()


# ---------------------------------------------------------------------------
# PaperMC v3
# ---------------------------------------------------------------------------

@pytest.mark.contract
def test_paper_v3_project_returns_version_group_map(paper_projects):
    """``/v3/projects/paper`` exposes ``versions`` as a group map.

    ``get_latest_stable_mc_version`` iterates ``resp.json()["versions"]``
    as ``dict.values()``, so the outer shape must be a dict/map.
    """
    assert isinstance(paper_projects, dict), (
        "Paper /projects/paper must return a JSON object"
    )
    assert "versions" in paper_projects, "Missing top-level 'versions' key"
    versions = paper_projects["versions"]
    assert isinstance(versions, dict), "'versions' must be a group map, not a list"
    assert versions, "'versions' must not be empty"

    for group_key, group_versions in versions.items():
        assert isinstance(group_key, str), f"Group key must be str, got {type(group_key)}"
        assert isinstance(group_versions, list), (
            f"Group '{group_key}' must map to a list"
        )


@pytest.mark.contract
def test_paper_v3_latest_version_key_is_semver(paper_projects):
    """At least one version entry matches the release-format regex the
    production code uses to filter out RC / pre / snapshot strings."""
    candidates: list[str] = []
    for group_versions in paper_projects["versions"].values():
        candidates.extend(group_versions)

    assert candidates, "PaperMC returned no version candidates at all"

    release_candidates = [v for v in candidates if SEMVER_RE.match(v)]
    assert release_candidates, (
        "No release-format versions found — production regex would reject everything"
    )


@pytest.mark.contract
def test_paper_v3_builds_is_flat_array_with_expected_shape(paper_builds_stable):
    """``/versions/{v}/builds?channel=STABLE`` returns a **flat list** (not
    a ``{"builds": [...]}`` dict).

    This is the exact regression from cmd_328 handoff_notes #2: the v2
    API returned a dict, the v3 API returns a list, and production code
    iterates the response directly. If upstream ever changes this shape
    again, this test catches it before the daily auto-update breaks.
    """
    _version, builds = paper_builds_stable

    assert isinstance(builds, list), (
        "PaperMC v3 builds must be a flat array (cmd_328 handoff_notes #2)"
    )
    assert builds, (
        "STABLE builds list came back empty even after fixture fallback — "
        "this should have failed in the fixture"
    )

    for build in builds:
        assert isinstance(build, dict)
        assert isinstance(build.get("id"), int), "build.id must be int"
        assert isinstance(build.get("time"), str), "build.time must be str"
        assert ISO8601_RE.match(build["time"]), (
            f"build.time '{build['time']}' must be ISO8601"
        )
        assert isinstance(build.get("channel"), str), "build.channel must be str"
        assert build["channel"] in PAPER_CHANNELS, (
            f"Unknown channel '{build['channel']}', expected one of {PAPER_CHANNELS}"
        )

    assert builds[0]["channel"] == "STABLE", (
        "With ?channel=STABLE filter, first element must be STABLE"
    )


# ---------------------------------------------------------------------------
# Modrinth v2
# ---------------------------------------------------------------------------

@pytest.mark.contract
def test_modrinth_v2_project_metadata_shape(modrinth_fabric_api_project):
    """``/v2/project/{slug}`` exposes id/project_type/versions."""
    assert isinstance(modrinth_fabric_api_project, dict)
    assert isinstance(modrinth_fabric_api_project.get("id"), str), (
        "project.id must be str"
    )
    assert modrinth_fabric_api_project.get("project_type") == "mod", (
        f"fabric-api must be type 'mod', got "
        f"{modrinth_fabric_api_project.get('project_type')!r}"
    )
    assert isinstance(modrinth_fabric_api_project.get("versions"), list), (
        "project.versions must be list"
    )


@pytest.mark.contract
def test_modrinth_v2_project_versions_list_shape(modrinth_fabric_api_versions):
    """``/v2/project/{slug}/version`` returns a list of version records
    with the fields production code reads (version_number / game_versions
    / loaders / date_published)."""
    assert isinstance(modrinth_fabric_api_versions, list), (
        "versions endpoint must return a list"
    )
    assert modrinth_fabric_api_versions, "fabric-api must have at least one version"

    sample = modrinth_fabric_api_versions[0]
    assert isinstance(sample, dict)
    assert isinstance(sample.get("version_number"), str)
    assert isinstance(sample.get("game_versions"), list)
    assert isinstance(sample.get("loaders"), list)
    assert isinstance(sample.get("date_published"), str)
    assert ISO8601_RE.match(sample["date_published"]), (
        f"date_published '{sample['date_published']}' must be ISO8601"
    )


@pytest.mark.contract
def test_modrinth_v2_project_version_filter_by_loader_and_game_version():
    """``/v2/project/{slug}/version?loaders=[...]&game_versions=[...]``
    still accepts JSON-array-in-string query params — this is the exact
    call shape used by ``check_mod_compatibility``.

    This is intentionally NOT session-cached: the filtered shape is a
    distinct contract from the unfiltered list.
    """
    resp = requests.get(
        f"{MODRINTH_API}/project/fabric-api/version",
        params={"loaders": '["fabric"]', "game_versions": '["1.21.1"]'},
        headers=HEADERS,
        timeout=TIMEOUT,
    )
    resp.raise_for_status()
    versions = resp.json()

    assert isinstance(versions, list), "Filtered versions must be a list"
    for v in versions:
        assert "fabric" in v.get("loaders", []), (
            f"Filter leaked non-fabric version: {v.get('loaders')!r}"
        )
        assert "1.21.1" in v.get("game_versions", []), (
            f"Filter leaked non-1.21.1 version: {v.get('game_versions')!r}"
        )


@pytest.mark.contract
def test_modrinth_v2_version_record_has_files_shape(modrinth_fabric_api_versions):
    """Each version record exposes a non-empty ``files`` list whose primary
    entry has ``filename`` and ``url`` (production reads ``files[0]``)."""
    assert modrinth_fabric_api_versions, (
        "fabric-api must have at least one version to inspect"
    )

    sample = modrinth_fabric_api_versions[0]
    files = sample.get("files")
    assert isinstance(files, list), "version.files must be a list"
    assert files, "version.files must be non-empty"

    primary = files[0]
    assert isinstance(primary, dict)
    assert isinstance(primary.get("filename"), str), "files[0].filename must be str"
    assert isinstance(primary.get("url"), str), "files[0].url must be str"
    assert primary["url"].startswith("https://"), (
        f"files[0].url must be HTTPS, got {primary['url']!r}"
    )


@pytest.mark.contract
def test_modrinth_v2_version_dependencies_shape(modrinth_fabric_api_versions):
    """``/v2/version/{id}`` exposes a ``dependencies`` list with
    ``dependency_type`` and optionally ``project_id`` (production filters
    for ``required`` to detect missing mods)."""
    assert modrinth_fabric_api_versions, "Need at least one version id to probe"
    version_id = modrinth_fabric_api_versions[0]["id"]

    resp = requests.get(
        f"{MODRINTH_API}/version/{version_id}",
        headers=HEADERS,
        timeout=TIMEOUT,
    )
    resp.raise_for_status()
    body = resp.json()

    deps = body.get("dependencies")
    assert isinstance(deps, list), "version.dependencies must be a list"
    for dep in deps:
        assert isinstance(dep, dict)
        assert isinstance(dep.get("dependency_type"), str), (
            "dep.dependency_type must be str"
        )
        project_id = dep.get("project_id")
        assert project_id is None or isinstance(project_id, str), (
            "dep.project_id must be str or null"
        )


@pytest.mark.contract
def test_modrinth_v2_tag_game_version_shape():
    """``/v2/tag/game_version`` returns a list of ``{version, version_type}``
    records whose ``version_type`` is one of the documented values."""
    resp = requests.get(
        f"{MODRINTH_API}/tag/game_version",
        headers=HEADERS,
        timeout=TIMEOUT,
    )
    resp.raise_for_status()
    tags = resp.json()

    assert isinstance(tags, list), "tag/game_version must return a list"
    assert tags, "tag/game_version must not be empty"

    for tag in tags:
        assert isinstance(tag, dict)
        assert isinstance(tag.get("version"), str), "tag.version must be str"
        vtype = tag.get("version_type")
        assert isinstance(vtype, str), "tag.version_type must be str"
        assert vtype in MODRINTH_VERSION_TYPES, (
            f"Unknown version_type '{vtype}', expected one of {MODRINTH_VERSION_TYPES}"
        )

    assert any(t["version_type"] == "release" for t in tags), (
        "No release-type versions — production would filter everything out"
    )


# ---------------------------------------------------------------------------
# Fabric Meta v2
# ---------------------------------------------------------------------------

@pytest.mark.contract
def test_fabric_meta_loader_list_shape(fabric_loader_list):
    """``/v2/versions/loader`` returns a list whose entries expose
    ``version`` / ``stable`` / ``build`` (production reads all three)."""
    assert isinstance(fabric_loader_list, list), "Fabric loader list must be a list"
    assert fabric_loader_list, "Fabric loader list must not be empty"

    for entry in fabric_loader_list:
        assert isinstance(entry, dict)
        assert isinstance(entry.get("version"), str), "loader.version must be str"
        assert isinstance(entry.get("stable"), bool), "loader.stable must be bool"
        assert isinstance(entry.get("build"), int), "loader.build must be int"


@pytest.mark.contract
def test_fabric_meta_loader_has_at_least_one_stable_entry(fabric_loader_list):
    """Production aborts when no stable loader exists; the daily probe
    warns us before that happens in the auto-update job."""
    assert any(entry.get("stable") is True for entry in fabric_loader_list), (
        "No stable Fabric loader in manifest — auto-update would fail"
    )


@pytest.mark.contract
def test_fabric_meta_loader_for_mc_version_shape():
    """``/v2/versions/loader/{mc_version}`` returns a list of entries
    whose ``loader`` sub-dict exposes ``version`` / ``stable`` (production
    reads ``entry["loader"]["version"]`` when ``stable`` is true)."""
    resp = requests.get(
        f"{FABRIC_META}/{FABRIC_PROBE_MC_VERSION}",
        headers=HEADERS,
        timeout=TIMEOUT,
    )
    resp.raise_for_status()
    entries = resp.json()

    assert isinstance(entries, list), "Per-version loader list must be a list"
    assert entries, f"No Fabric loaders for {FABRIC_PROBE_MC_VERSION}"

    for entry in entries:
        loader = entry.get("loader")
        assert isinstance(loader, dict), "entry.loader must be a dict"
        assert isinstance(loader.get("version"), str), "loader.version must be str"
        assert isinstance(loader.get("stable"), bool), "loader.stable must be bool"
