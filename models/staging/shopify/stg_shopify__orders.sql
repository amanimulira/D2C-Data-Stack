with source as (

    select * from {{ source('shopify', 'shopify_orders') }}

),

renamed as (

    select
        order_id,
        order_number,
        customer_id,

        -- Timestamps
        created_at      as ordered_at,
        processed_at    as processed_at,
        cast(created_at as date) as order_date,

        -- Status
        financial_status,
        fulfillment_status,
        case
            when financial_status in ('refunded', 'partially_refunded') then true
            else false
        end as has_refund,

        -- Money (already in major units in this seed; in production from Shopify
        -- the raw subtotal_price is in major units but inventory APIs return cents).
        currency,
        subtotal_price   as order_subtotal,
        total_tax        as order_tax,
        total_discounts  as order_discount,
        total_shipping   as order_shipping,
        total_price      as order_total,
        subtotal_price - total_discounts                as net_merchandise_value,

        -- Marketing attribution captured at checkout
        coalesce(nullif(utm_source,   ''), '(direct)')     as utm_source,
        coalesce(nullif(utm_medium,   ''), '(none)')       as utm_medium,
        coalesce(nullif(utm_campaign, ''), '(not set)')    as utm_campaign,
        source_name,
        referring_site

    from source

)

select * from renamed
