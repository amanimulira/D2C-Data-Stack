# Data Modeling

## Layer responsibilities

| Layer | Materialization | Owns |
|---|---|---|
| `staging` | view | One-to-one with raw tables. Renames columns to `snake_case`, casts types, normalizes empty strings, and applies a controlled vocabulary to enums. **No joins.** |
| `intermediate` | ephemeral | Joins and rollups that more than one mart needs. Never exposed to BI. |
| `marts/core` | table | The order graph: `dim_customers`, `dim_products`, `dim_dates`, `fct_orders`, `fct_order_items`. |
| `marts/marketing` | table | Spend, attribution, blended ROAS. |
| `marts/customer` | table | LTV, cohort retention, RFM. |

## Naming convention

Follows the [dbt Labs canonical guide](https://docs.getdbt.com/best-practices/how-we-structure/2-staging):

```
stg_<source>__<entity>      # stg_shopify__orders
int_<entity>__<verb>        # int_customers__order_history
fct_<entity>                # fct_orders
dim_<entity>                # dim_customers
```

Column naming: `<entity>_<attribute>` for context. `order_total`, `customer_email`,
`product_cost`. Surrogate keys end in `_sk`. Boolean columns start with `is_` or
`has_`. Timestamps end in `_at`, dates in `_date`.

## Grain decisions

| Model | Grain | Rationale |
|---|---|---|
| `fct_orders` | One row per Shopify order | The native unit of revenue for a D2C brand. Refunds are rolled into the same row to avoid double-counting. |
| `fct_order_items` | One row per line item per order | Required for product-mix and per-SKU margin analysis. Joins back to `fct_orders` for order-level context. |
| `fct_marketing_performance` | Daily × platform × campaign | Matches how operators set budgets and how platforms expose data. |
| `customer_cohort_retention` | Cohort month × months-since-acquisition | Standard cohort matrix grain. |
| `fct_blended_roas` | Daily | Blended is meaningless at the campaign grain (no causal link); daily is the finest grain that's still honest. |

## Tests in use

- **Schema tests** (declared in YAML): `unique`, `not_null`, `accepted_values`,
  `relationships`, plus `dbt_utils.unique_combination_of_columns` for composite
  keys.
- **Distributional tests** via `dbt-expectations`:
  `expect_column_values_to_be_between` for things like `0 <= ctr <= 1`,
  `0 <= retention_rate <= 1`, `spend >= 0`.
- **Singular tests** in `tests/`: `assert_no_future_orders`,
  `assert_positive_revenue`, `assert_attribution_coverage`,
  `assert_cohort_retention_in_bounds`. These encode invariants that are
  cheaper to test than to type-system.
- **Source freshness** in `_<source>__sources.yml` — `warn_after` and
  `error_after` thresholds catch upstream pipeline failures before they
  surface as missing rows in the BI layer.

## Macros

| Macro | Purpose |
|---|---|
| `normalize_email` | Lowercase + trim + null-on-empty. The deterministic identity key for joining Shopify customers to Klaviyo profiles. |
| `cents_to_dollars` | Convert minor-unit money columns (Stripe, Shopify cart APIs) into major units at the staging boundary. |
| `unioned_marketing_spend` | Loops over an extensible `(model, platform_label)` list to union per-platform spend models. Adding Google Ads is a one-line change. |
| `generate_schema_name` | Project-wide override so custom schemas in `dbt_project.yml` materialize verbatim instead of being concatenated with the target schema. |
