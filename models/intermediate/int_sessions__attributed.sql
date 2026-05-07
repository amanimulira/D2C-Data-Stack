{#
    GA4 sessions tagged with the order they led to (if any). The link from
    `user_pseudo_id` to a Shopify customer is the canonical D2C identity-stitch
    problem. Here we use a simplification that's true in this seed: each GA4
    session ending in a `purchase` event maps to exactly one Shopify order on
    the same day & UTM. In production, the stitch is deterministic via a
    post-purchase user_id event written to GA4 by the storefront.
#}

with sessions as (

    select * from {{ ref('stg_ga4__sessions') }}

),

orders as (

    select
        order_id,
        customer_id,
        ordered_at,
        order_date,
        utm_source,
        utm_medium,
        utm_campaign
    from {{ ref('int_orders__joined') }}

),

session_to_order as (

    select
        s.user_pseudo_id,
        s.session_id,
        s.session_started_at,
        s.session_date,
        s.session_number,
        s.session_source,
        s.session_medium,
        s.session_campaign,
        s.had_page_view,
        s.had_view_item,
        s.had_add_to_cart,
        s.had_begin_checkout,
        s.had_purchase,
        s.page_view_count,
        s.purchase_value,

        o.order_id,
        o.customer_id

    from sessions s
    left join orders o
           on s.had_purchase = 1
          and s.session_date = o.order_date
          and s.session_source   = o.utm_source
          and s.session_medium   = o.utm_medium
          and s.session_campaign = o.utm_campaign

)

select * from session_to_order
