"""Unit tests for scripts/check-mc-update.py.

Mocks every outbound HTTP call with the ``responses`` library. Fixtures are
loaded via ``json_fixture()`` from ``conftest.py``, which enforces that
PaperMC v3 builds responses are flat JSON arrays (cmd_328 handoff_notes #2).
"""
from __future__ import annotations

import pytest
import responses

from tests.conftest import json_fixture


# ---------------------------------------------------------------------------
# Regex / pure-logic checks (no HTTP)
# ---------------------------------------------------------------------------

def test_stable_version_re_matches_release_not_rc(check_mc_update):
    """STABLE_VERSION_RE accepts `^\\d+\\.\\d+(\\.\\d+)?$` release strings."""
    assert check_mc_update.STABLE_VERSION_RE.match("1.21.11")
    assert check_mc_update.STABLE_VERSION_RE.match("1.21")
    assert check_mc_update.STABLE_VERSION_RE.match("26.1.2")


def test_stable_version_re_rejects_pre_release_strings(check_mc_update):
    """RC / pre / snapshot suffixes must not match."""
    assert not check_mc_update.STABLE_VERSION_RE.match("1.21.11-rc3")
    assert not check_mc_update.STABLE_VERSION_RE.match("1.21-pre5")
    assert not check_mc_update.STABLE_VERSION_RE.match("1.21.11-SNAPSHOT")
    assert not check_mc_update.STABLE_VERSION_RE.match("25w01a")


def test_parse_major_returns_first_two_components(check_mc_update):
    assert check_mc_update.parse_major("1.21.11") == ["1", "21"]
    assert check_mc_update.parse_major("1.21") == ["1", "21"]
    assert check_mc_update.parse_major("26.1.2") == ["26", "1"]


def test_is_major_update_detects_major_change(check_mc_update):
    assert check_mc_update.is_major_update("1.20.6", "1.21.11") is True
    assert check_mc_update.is_major_update("1.21.10", "1.21.11") is False
    assert check_mc_update.is_major_update("1.21", "26.1.2") is True


# ---------------------------------------------------------------------------
# PaperMC v3 — get_latest_stable_mc_version
# ---------------------------------------------------------------------------

def test_get_latest_stable_mc_version_flattens_groups_and_returns_first_stable(
    mocked_responses, check_mc_update,
):
    """Happy path: groups dict is flattened in insertion order; first STABLE
    build wins.

    The realistic snapshot fixture puts 26.1 (next-major, ALPHA-only) before
    1.21, exercising: (1) insertion-order flatten, (2) RC regex filtering,
    (3) skipping candidates whose builds are all ALPHA, (4) early return on
    the first STABLE match.
    """
    paper_api = check_mc_update.PAPER_API
    mocked_responses.add(
        responses.GET,
        paper_api,
        json=json_fixture("papermc_v3_projects_paper.json"),
        status=200,
    )
    # 26.1.x — all ALPHA, should be skipped
    for v in ("26.1.2", "26.1.1", "26.1.0"):
        mocked_responses.add(
            responses.GET,
            f"{paper_api}/versions/{v}/builds",
            json=json_fixture("papermc_v3_builds_alpha_only.json"),
            status=200,
        )
    # 1.21.11 has STABLE — function should return here
    mocked_responses.add(
        responses.GET,
        f"{paper_api}/versions/1.21.11/builds",
        json=json_fixture("papermc_v3_builds_stable.json"),
        status=200,
    )
    # 1.21.11-rc3 fails regex → never fetched. 1.21.10 / 1.20.6 are after
    # early return → never fetched. Do not mock those URLs.

    result = check_mc_update.get_latest_stable_mc_version()
    assert result == "1.21.11"


def test_get_latest_stable_mc_version_early_returns_at_first_stable(
    mocked_responses, check_mc_update,
):
    """After finding a STABLE build, subsequent builds endpoints must NOT
    be called (cost / rate-limit control)."""
    paper_api = check_mc_update.PAPER_API
    mocked_responses.add(
        responses.GET,
        paper_api,
        json=json_fixture("papermc_v3_projects_paper.json"),
        status=200,
    )
    for v in ("26.1.2", "26.1.1", "26.1.0"):
        mocked_responses.add(
            responses.GET,
            f"{paper_api}/versions/{v}/builds",
            json=json_fixture("papermc_v3_builds_alpha_only.json"),
            status=200,
        )
    mocked_responses.add(
        responses.GET,
        f"{paper_api}/versions/1.21.11/builds",
        json=json_fixture("papermc_v3_builds_stable.json"),
        status=200,
    )

    check_mc_update.get_latest_stable_mc_version()

    called_urls = [call.request.url for call in mocked_responses.calls]
    # Projects + 26.1.x (3) + 1.21.11 = 5 calls total. Nothing after 1.21.11.
    assert len(called_urls) == 5
    assert called_urls[-1].endswith("/versions/1.21.11/builds")
    assert not any("1.21.10" in u or "1.20.6" in u for u in called_urls)


def test_get_latest_stable_mc_version_returns_none_when_all_alpha(
    mocked_responses, check_mc_update,
):
    """When every release-format candidate only has ALPHA builds, return
    None (caller will exit 1 upstream)."""
    paper_api = check_mc_update.PAPER_API
    projects_all_alpha = {
        "project": {"id": "paper", "name": "Paper"},
        "versions": {"26.1": ["26.1.2", "26.1.1"]},
    }
    mocked_responses.add(
        responses.GET, paper_api, json=projects_all_alpha, status=200,
    )
    for v in ("26.1.2", "26.1.1"):
        mocked_responses.add(
            responses.GET,
            f"{paper_api}/versions/{v}/builds",
            json=json_fixture("papermc_v3_builds_alpha_only.json"),
            status=200,
        )

    assert check_mc_update.get_latest_stable_mc_version() is None


def test_get_latest_stable_mc_version_skips_rc_versions_without_http_call(
    mocked_responses, check_mc_update,
):
    """A candidate failing STABLE_VERSION_RE must not trigger a builds
    request — this keeps snapshot / RC noise from eating rate-limit budget."""
    paper_api = check_mc_update.PAPER_API
    projects = {
        "project": {"id": "paper", "name": "Paper"},
        "versions": {"1.21": ["1.21.11-rc3", "1.21.11"]},
    }
    mocked_responses.add(responses.GET, paper_api, json=projects, status=200)
    mocked_responses.add(
        responses.GET,
        f"{paper_api}/versions/1.21.11/builds",
        json=json_fixture("papermc_v3_builds_stable.json"),
        status=200,
    )

    check_mc_update.get_latest_stable_mc_version()

    called_urls = [call.request.url for call in mocked_responses.calls]
    assert not any("1.21.11-rc3" in u for u in called_urls)


def test_get_latest_stable_mc_version_sends_user_agent(
    mocked_responses, check_mc_update,
):
    """PaperMC docs recommend a User-Agent. Regression guard: strip the
    header in the production code and this test fails."""
    paper_api = check_mc_update.PAPER_API
    projects = {
        "project": {"id": "paper", "name": "Paper"},
        "versions": {"1.21": ["1.21.11"]},
    }
    mocked_responses.add(responses.GET, paper_api, json=projects, status=200)
    mocked_responses.add(
        responses.GET,
        f"{paper_api}/versions/1.21.11/builds",
        json=json_fixture("papermc_v3_builds_stable.json"),
        status=200,
    )

    check_mc_update.get_latest_stable_mc_version()

    for call in mocked_responses.calls:
        assert "User-Agent" in call.request.headers
        assert "jln-hut-modpack" in call.request.headers["User-Agent"]


# ---------------------------------------------------------------------------
# Modrinth
# ---------------------------------------------------------------------------

def test_get_modrinth_supported_versions_filters_to_release_only(
    mocked_responses, check_mc_update,
):
    """Snapshot / pre-release version_types must be filtered out."""
    mocked_responses.add(
        responses.GET,
        f"{check_mc_update.MODRINTH_API}/tag/game_version",
        json=json_fixture("modrinth_game_versions.json"),
        status=200,
    )

    versions = check_mc_update.get_modrinth_supported_versions()

    assert isinstance(versions, set)
    assert "1.21.11" in versions
    assert "1.21.10" in versions
    assert "1.21" in versions
    assert "1.20.6" in versions
    # snapshots must be excluded
    assert "1.21.11-rc3" not in versions
    assert "1.21-pre5" not in versions


def test_check_mod_compatibility_returns_versions_when_compatible(
    mocked_responses, check_mc_update,
):
    mocked_responses.add(
        responses.GET,
        f"{check_mc_update.MODRINTH_API}/project/P1AbCd2E/version",
        json=json_fixture("modrinth_project_version_compat.json"),
        status=200,
    )

    versions = check_mc_update.check_mod_compatibility("P1AbCd2E", "1.21.11")

    assert isinstance(versions, list)
    assert len(versions) == 2
    assert versions[0]["id"] == "abcDEF12"
    assert versions[0]["files"][0]["filename"].endswith(".jar")


def test_check_mod_compatibility_returns_empty_list_when_incompatible(
    mocked_responses, check_mc_update,
):
    """Empty list signals non-compatibility; ``main()`` appends the mod
    name to ``incompatible`` based on this falsy check."""
    mocked_responses.add(
        responses.GET,
        f"{check_mc_update.MODRINTH_API}/project/UNCOMPAT1/version",
        json=json_fixture("modrinth_project_version_empty.json"),
        status=200,
    )

    versions = check_mc_update.check_mod_compatibility("UNCOMPAT1", "1.21.11")

    assert versions == []


def test_get_mod_dependencies_returns_required_and_optional_deps(
    mocked_responses, check_mc_update,
):
    """Returns the raw ``dependencies`` list — the main() aggregation layer
    filters by ``dependency_type == 'required'`` against ``known_ids``."""
    mocked_responses.add(
        responses.GET,
        f"{check_mc_update.MODRINTH_API}/version/abcDEF12",
        json=json_fixture("modrinth_version_deps.json"),
        status=200,
    )

    deps = check_mc_update.get_mod_dependencies("abcDEF12")

    assert isinstance(deps, list)
    assert len(deps) == 3
    required = [d for d in deps if d.get("dependency_type") == "required"]
    assert {d["project_id"] for d in required} == {"KNOWN123", "UNKNOWN9"}
    optional = [d for d in deps if d.get("dependency_type") == "optional"]
    assert [d["project_id"] for d in optional] == ["OPTDEP01"]


def test_get_mod_dependencies_returns_empty_list_when_key_missing(
    mocked_responses, check_mc_update,
):
    """If the upstream response lacks a ``dependencies`` key, return []
    rather than raising (``.get("dependencies", [])``)."""
    mocked_responses.add(
        responses.GET,
        f"{check_mc_update.MODRINTH_API}/version/noDeps123",
        json={"id": "noDeps123", "project_id": "X"},
        status=200,
    )

    assert check_mc_update.get_mod_dependencies("noDeps123") == []


# ---------------------------------------------------------------------------
# Fabric Meta
# ---------------------------------------------------------------------------

def test_get_fabric_loader_version_returns_first_stable(
    mocked_responses, check_mc_update,
):
    """Fabric Meta returns newest-first; first ``stable=true`` entry wins."""
    mocked_responses.add(
        responses.GET,
        f"{check_mc_update.FABRIC_META}/1.21.11",
        json=json_fixture("fabric_loader.json"),
        status=200,
    )

    version = check_mc_update.get_fabric_loader_version("1.21.11")

    # 0.16.9 is first stable in fixture; 0.16.8-beta.1 is a later-listed beta
    assert version == "0.16.9"


def test_get_fabric_loader_version_returns_none_when_all_unstable(
    mocked_responses, check_mc_update,
):
    mocked_responses.add(
        responses.GET,
        f"{check_mc_update.FABRIC_META}/1.21.11",
        json=json_fixture("fabric_loader_unstable_only.json"),
        status=200,
    )

    assert check_mc_update.get_fabric_loader_version("1.21.11") is None


# ---------------------------------------------------------------------------
# Fixture integrity guard
# ---------------------------------------------------------------------------

@pytest.mark.parametrize(
    "fixture_name",
    [
        "papermc_v3_builds_stable.json",
        "papermc_v3_builds_alpha_only.json",
    ],
)
def test_papermc_builds_fixtures_are_flat_arrays(fixture_name):
    """cmd_328 handoff_notes #2: v3 builds is a flat array, never dict-wrapped.

    Duplicates the runtime assertion in ``conftest.json_fixture`` to make
    the contract explicit in the test report.
    """
    data = json_fixture(fixture_name)
    assert isinstance(data, list)
    assert len(data) >= 1
    for build in data:
        assert set(build.keys()) >= {
            "channel", "id", "time", "downloads", "commits",
        }
