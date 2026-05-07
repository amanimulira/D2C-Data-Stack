{#
    Line-grain fact. One row per SKU per order. Useful for product-mix analysis,
    BOGO/discount diagnostics, and per-SKU contribution margin.
#}

with lines as (

    select * from {{ ref('stg_shopify__order_lines') }}

),

orders as (

    select * from {{ ref('int_orders__joined') }}

),

products as (

    select product_id, product_cost, product_title, product_type
    from {{ ref('stg_shopify__products') }}

)

select
    l.order_line_id,
    l.order_id,
    o.customer_id,
    o.order_date,

    l.product_id,
    p.product_title,
    p.product_type,
    l.sku,

    l.quantity,
    l.unit_price,
    l.line_discount,
    l.gross_line_revenue,
    l.net_line_revenue,

    coalesce(p.product_cost, 0)                                       as unit_cost,
    l.quantity * coalesce(p.product_cost, 0)                          as line_cogs,
    l.net_line_revenue - l.quantity * coalesce(p.product_cost, 0)     as line_gross_margin,

    o.utm_source,
    o.utm_medium,
    o.utm_campaign

from lines l
join orders   o on l.order_id    = o.order_id
left join products p on l.product_id = p.product_id
