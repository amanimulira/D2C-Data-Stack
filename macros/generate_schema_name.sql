{#
    Override of dbt's default `generate_schema_name`. Without this, a custom
    schema declared in dbt_project.yml (e.g. `+schema: raw_shopify`) is
    concatenated with the target's default schema, producing names like
    `dbt_dev_raw_shopify`. We want schemas to materialize verbatim so that
    `source('shopify', 'orders')` resolves consistently across dev, CI, and
    prod targets.

    For multi-developer sandboxing, swap this macro for the dbt Labs alternative
    pattern (target-prefixed schemas in non-prod) — see:
    https://docs.getdbt.com/docs/build/custom-schemas
#}

{% macro generate_schema_name(custom_schema_name, node) -%}

    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}

{%- endmacro %}
