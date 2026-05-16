# `streamlit_app/` — executive dashboard

Light-theme, board-pack-style Streamlit dashboard over the dbt marts in
this repo. Sister to [`bi/`](../bi/) (which is the same data rendered in
Evidence) — same SQL, two presentation layers.

## Pages

| File | Page | What it shows |
|---|---|---|
| `Home.py` | Executive summary | Headline KPIs, daily revenue vs spend, channel split |
| `pages/1_Marketing.py` | Marketing performance | Three ROAS views, daily blended MER, campaign table, spend ramp |
| `pages/2_Customers.py` | Customer analytics | Cohort retention heatmap, LTV by channel, RFM segments |
| `pages/3_Orders.py` | Orders & products | Order economics, daily volume, per-SKU margin profile |

## Run locally

From repo root:

```bash
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt -r streamlit_app/requirements.txt
export DBT_PROFILES_DIR="$(pwd)"
cp -n profiles.yml.example profiles.yml
dbt deps && dbt seed && dbt run        # build d2c_stack.duckdb (~30s)
streamlit run streamlit_app/Home.py
```

If `d2c_stack.duckdb` doesn't exist when Streamlit launches, the app
runs `dbt seed && dbt run` on the first query — cold-start adds ~45s.
Subsequent queries hit the cached DuckDB file directly.

## Deploy to Streamlit Community Cloud

1. Sign in at [share.streamlit.io](https://share.streamlit.io) with the
   GitHub account that owns this repo.
2. Click **New app** and select:
   - **Repository**: `amanimulira/D2C-Data-Stack`
   - **Branch**: `main`
   - **Main file path**: `streamlit_app/Home.py`
3. Under **Advanced settings → App URL**, pick the subdomain you want
   (e.g. `d2c-data-stack` → resolves to `d2c-data-stack.streamlit.app`).
4. Click **Deploy**.

The Python version (3.11) is pinned via the repo-root `.python-version`
file. Don't override it in the deploy UI — `dbt-core 1.8` doesn't yet
support Python 3.13+ and Pillow (pulled in by Streamlit) has no wheel
for 3.14, so newer Python versions will fail to install.

Streamlit Cloud reads `streamlit_app/requirements.txt` for Python deps
and `streamlit_app/.streamlit/config.toml` for the theme. The first
deployment takes ~3 min (installs dbt-duckdb, runs `dbt seed && dbt run`
on the first page hit). Subsequent loads are sub-second.

## Visual style

Light theme tuned for an executive-report feel — serif headings
(Charter / Georgia), restrained slate palette, single deep-blue accent.
All charts are Altair (Vega-Lite) so the theme is consistent across
pages. CSS overrides live in [`lib/style.py`](lib/style.py); colour
tokens are exported as `EXEC_PALETTE` so individual charts can reach for
them when they need to.

## Architecture notes

- **`lib/data.py`** — `query(sql)` is the single entrypoint. Wraps
  DuckDB connections in `st.cache_data`, opens a fresh read-only handle
  per call so Streamlit's thread pool never contends on a shared cursor.
- **`lib/style.py`** — `apply_theme()` injects the CSS and registers the
  Altair theme. Idempotent; safe to call at the top of every page.
- **No cross-page state** — every page is independently runnable.
  Bookmarkable URLs, no session-leak surprises.
