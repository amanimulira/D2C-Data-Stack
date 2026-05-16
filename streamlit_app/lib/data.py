"""DuckDB connection + dbt-build-on-cold-start helper.

Streamlit Community Cloud spins up an ephemeral container on each redeploy
— there's no persistent `d2c_stack.duckdb` on disk. On the very first
query we run `dbt seed && dbt run` to materialize the marts from the
synthetic CSV seeds shipped in the repo. Subsequent queries hit the
DuckDB file directly and are memoized by Streamlit's data cache.
"""
from __future__ import annotations

import os
import pathlib
import shutil
import subprocess
import sys

import duckdb
import pandas as pd
import streamlit as st

REPO_ROOT = pathlib.Path(__file__).resolve().parents[2]
DB_PATH = REPO_ROOT / "d2c_stack.duckdb"
PROFILES_TEMPLATE = REPO_ROOT / "profiles.yml.example"
PROFILES_TARGET = REPO_ROOT / "profiles.yml"


def _ensure_profiles_yml() -> None:
    """dbt-duckdb needs a profiles.yml on disk; clone from the committed
    .example if the user hasn't already created one locally."""
    if not PROFILES_TARGET.exists():
        shutil.copy(PROFILES_TEMPLATE, PROFILES_TARGET)


def _run_dbt() -> None:
    """Invoke dbt as a subprocess. We don't use the dbt Programmatic API
    because it leaks logging state into Streamlit's event loop and the CLI
    is the path users themselves would run."""
    _ensure_profiles_yml()
    env = {**os.environ, "DBT_PROFILES_DIR": str(REPO_ROOT)}

    for cmd in (["dbt", "deps"], ["dbt", "seed", "--full-refresh"], ["dbt", "run"]):
        result = subprocess.run(
            cmd, cwd=REPO_ROOT, env=env, capture_output=True, text=True
        )
        if result.returncode != 0:
            # Surface dbt's error in the Streamlit UI rather than dying silently.
            st.error(f"`{' '.join(cmd)}` failed.\n\n```\n{result.stderr[-2000:]}\n```")
            raise RuntimeError(f"{' '.join(cmd)} exited {result.returncode}")


@st.cache_resource(show_spinner="Building marts from raw seeds (cold start, ~45s)…")
def ensure_marts_built() -> pathlib.Path:
    """Idempotent: builds the DuckDB file once per app process."""
    if not DB_PATH.exists():
        _run_dbt()
    return DB_PATH


@st.cache_data(ttl=3600, show_spinner=False)
def query(sql: str) -> pd.DataFrame:
    """Run a read-only SQL query against the dbt-built DuckDB file.

    Results are memoized for an hour — the underlying data is static within
    a deployment, so cache hits across pages are essentially free.
    """
    db_path = ensure_marts_built()
    # Open a fresh connection per call so Streamlit's threading model never
    # contends with concurrent readers on a shared cursor.
    with duckdb.connect(str(db_path), read_only=True) as con:
        return con.execute(sql).df()
