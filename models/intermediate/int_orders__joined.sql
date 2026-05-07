{#
    Order-grain enrichment. One row per order, with refund totals rolled up and
    customer email attached. This is the workhorse input for fct_orders and the
    customer marts.
#}

with orders as (

    select * from {{ ref('stg_shopify__orders') }}

),

customers as (

    select customer_id, email, country_code, customer_created_at
    from {{ ref('stg_shopify__customers') }}

),

refunds_rolled as (

    select
        order_id,
        sum(refund_amount)             as total_refund_amount,
        count(*)                       as refund_count,
        max(refunded_at)               as last_refunded_at
    from {{ ref('stg_shopify__refunds') }}
    group by 1

),

joined as (

    select
        o.order_id,
        o.order_number,
        o.customer_id,
        c.email                                                       as customer_email,
        c.country_code                                                as customer_country_code,

        o.ordered_at,
        o.processed_at,
        o.order_date,

        o.financial_status,
        o.fulfillment_status,
        o.has_refund,

        o.currency,
        o.order_subtotal,
        o.order_tax,
        o.order_discount,
        o.order_shipping,
        o.order_total,
        o.net_merchandise_value,

        coalesce(r.total_refund_amount, 0)                            as refund_amount,
        coalesce(r.refund_count, 0)                                   as refund_count,
        o.order_subtotal - coalesce(r.total_refund_amount, 0)         as net_subtotal_after_refunds,

        o.utm_source,
        o.utm_medium,
        o.utm_campaign,
        o.source_name,
        o.referring_site

    from orders o
    left join customers       c on o.customer_id = c.customer_id
    left join refunds_rolled  r on o.order_id    = r.order_id

)

select * from joined
