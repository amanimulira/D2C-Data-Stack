# BI Dashboard (Evidence)

The accompanying static BI site for the Modern D2C Data Stack — an
[Evidence](https://evidence.dev) project that reads directly from the DuckDB
file produced by `dbt build`.

Four pages out of the box:

| Page | What it shows |
|---|---|
| [`/`](pages/index.md) | Top-line: net revenue, contribution margin, blended ROAS, daily revenue vs spend, channel split |
| [`/marketing`](pages/marketing.md) | Platform-reported vs last-touch ROAS, contribution-margin MER, campaign performance table |
| [`/customers`](pages/customers.md) | Cohort retention grid, LTV by acquisition channel, RFM lifecycle segments |
| [`/orders`](pages/orders.md) | Daily orders & AOV, top products by revenue, per-SKU margin |

Every chart is one SQL query against a documented dbt mart — no pre-aggregation, no hidden joins.

## Run locally

Prerequisites: Node.js 18+ and the dbt project must have been built at least
once (the `d2c_stack.duckdb` file at the repo root must exist).

```bash
# From the repo root, build the warehouse
dbt deps && dbt seed && dbt build --target duckdb

# From the bi/ folder, install + run
cd bi
npm install
npm run sources    # cache mart query results as parquet
npm run dev        # opens http://localhost:3000
```

To produce a static build:

```bash
npm run build      # outputs to bi/build/
```

## How it's wired

- `sources/d2c_stack/connection.yaml` points DuckDB at `../../../d2c_stack.duckdb`
  — the file produced by `dbt build` at the repo root.
- `evidence.config.yaml` registers only the `@evidence-dev/duckdb` plugin
  (other connectors stripped to keep `node_modules` lean).
- Pages live in `pages/`. Add a new `pages/foo.md` and it shows up at `/foo`.

## Deploying

The repo's `.github/workflows/deploy-evidence.yml` builds dbt + Evidence on
every push to `main` and publishes to GitHub Pages. Cloudflare Pages and Vercel
both work too — point the build command at `npm run build` (with `dbt build`
as a pre-step) and the output directory at `bi/build/`.
