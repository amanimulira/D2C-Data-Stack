{#
    Product dimension. Currently a thin pass-through over staging — the place to
    enrich with category groupings, supplier metadata, or a slowly-changing-
    dimension snapshot when product attributes change over time.
#}

with products as (

    select * from {{ ref('stg_shopify__products') }}

)

select
    product_id,
    {{ dbt_utils.generate_surrogate_key(['product_id']) }}     as product_sk,
    product_title,
    product_type,
    vendor,
    sku,
    currency,
    product_price,
    product_cost,
    product_unit_margin,
    product_margin_pct,
    product_status,
    product_created_at

from products
