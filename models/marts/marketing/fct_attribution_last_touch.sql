{#
    Last-touch attribution at the order grain. Each order is credited to the
    UTM source captured on *that order's checkout session*. This is what most
    BI tools report as "channel revenue" by default — useful for budget
    allocation, but understates upper-funnel channels like Brand Awareness.
#}

with orders as (

    select * from {{ ref('fct_orders') }}

)

select
    order_id,
    order_date,
    customer_id,

    utm_source                          as last_touch_source,
    utm_medium                          as last_touch_medium,
    utm_campaign                        as last_touch_campaign,

    net_subtotal_after_refunds          as attributed_revenue,
    contribution_margin                 as attributed_contribution_margin

from orders
