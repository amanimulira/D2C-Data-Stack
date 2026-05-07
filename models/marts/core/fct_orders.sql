{{
    config(
        materialized='incremental',
        unique_key='order_id',
        on_schema_change='append_new_columns'
    )
}}

{#
    Order-grain fact. One row per Shopify order with refunds rolled in, COGS
    summed from the order's line items, and contribution margin computed.

    Incremental strategy: process only orders updated since the last run. In
    Shopify, `processed_at` advances on payment capture and refund events, so
    using it as the high-watermark catches both new orders and revisions.
#}

with orders as (

    select * from {{ ref('int_orders__joined') }}

    {% if is_incremental() %}
        where processed_at >= (select coalesce(max(processed_at), '1900-01-01') from {{ this }})
    {% endif %}

),

line_costs as (

    select
        l.order_id,
        sum(l.quantity * coalesce(p.product_cost, 0))                  as order_cogs,
        count(*)                                                       as line_count,
        sum(l.quantity)                                                as units_ordered
    from {{ ref('stg_shopify__order_lines') }} l
    left join {{ ref('stg_shopify__products') }} p
           on l.product_id = p.product_id
    group by 1

),

joined as (

    select
        o.order_id,
        o.order_number,
        o.customer_id,
        o.customer_email,
        o.customer_country_code,

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
        o.refund_amount,
        o.refund_count,
        o.net_subtotal_after_refunds,

        coalesce(lc.order_cogs, 0)                                     as order_cogs,
        coalesce(lc.line_count, 0)                                     as line_count,
        coalesce(lc.units_ordered, 0)                                  as units_ordered,

        -- Contribution margin = net merchandise value after refunds, less COGS,
        -- less the merchant-borne shipping cost (we treat shipping charged to
        -- the customer as cost-recovery, so we subtract shipping cost = 0 here;
        -- in production this would deduct fulfillment + payment processing).
        o.net_subtotal_after_refunds - coalesce(lc.order_cogs, 0)     as contribution_margin,
        case
            when o.net_subtotal_after_refunds > 0
                then (o.net_subtotal_after_refunds - coalesce(lc.order_cogs, 0)) / o.net_subtotal_after_refunds
            else 0
        end                                                            as contribution_margin_pct,

        o.utm_source,
        o.utm_medium,
        o.utm_campaign,
        o.source_name,
        o.referring_site

    from orders o
    left join line_costs lc on o.order_id = lc.order_id

)

select * from joined
