"""Shared pytest fixtures and helpers for mc-modpack tests.

The target module lives at ``scripts/check-mc-update.py`` — the hyphenated
filename is not importable via ``import``, so we load it via ``importlib``
and expose it as the ``check_mc_update`` fixture.
"""
from __future__ import annotations

import importlib.util
import json
import sys
from pathlib import Path
from types import ModuleType

import pytest
import responses

REPO_ROOT = Path(__file__).resolve().parent.parent
SCRIPT_PATH = REPO_ROOT / "scripts" / "check-mc-update.py"
FIXTURES_DIR = Path(__file__).resolve().parent / "fixtures"


def _load_check_mc_update() -> ModuleType:
    spec = importlib.util.spec_from_file_location("check_mc_update", SCRIPT_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Could not load spec for {SCRIPT_PATH}")
    module = importlib.util.module_from_spec(spec)
    sys.modules["check_mc_update"] = module
    spec.loader.exec_module(module)
    return module


def json_fixture(name: str):
    """Load a JSON fixture from tests/fixtures/.

    Enforces cmd_328 handoff_notes #2: PaperMC v3 ``builds`` responses are a
    flat JSON array, never ``{"builds": [...]}``. Asserting the shape at load
    time prevents v2-style dict-wrapped mocks from silently passing and
    makes the fixture contract self-documenting.
    """
    path = FIXTURES_DIR / name
    data = json.loads(path.read_text(encoding="utf-8"))
    if name.startswith("papermc_v3_builds"):
        assert isinstance(data, list), (
            f"{name}: PaperMC v3 builds fixture must be a flat list, "
            "not dict-wrapped. See cmd_328 handoff_notes #2."
        )
    return data


@pytest.fixture(scope="session")
def check_mc_update() -> ModuleType:
    """Import the hyphen-named script as a module for testing."""
    return _load_check_mc_update()


@pytest.fixture
def mocked_responses():
    """Activate responses.RequestsMock() for a single test.

    assert_all_requests_are_fired=False lets tests register fallback mocks
    (e.g. for early-return paths that only hit a subset).
    """
    with responses.RequestsMock(assert_all_requests_are_fired=False) as rsps:
        yield rsps
