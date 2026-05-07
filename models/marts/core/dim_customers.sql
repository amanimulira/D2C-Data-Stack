{#
    Customer dimension. Combines the Shopify customer record with lifetime
    purchase rollup and country reference data. This is the table BI tools
    join to for slicing every metric by customer attributes.
#}

with customers as (

    select * from {{ ref('stg_shopify__customers') }}

),

orders_rollup as (

    select * from {{ ref('int_customers__order_history') }}

),

countries as (

    select * from {{ ref('countries') }}

)

select
    c.customer_id,
    {{ dbt_utils.generate_surrogate_key(['c.customer_id']) }}                 as customer_sk,

    c.email,
    c.first_name,
    c.last_name,
    c.first_name || ' ' || c.last_name                                         as full_name,
    c.phone,

    c.country_code,
    co.country_name,
    co.region                                                                  as country_region,

    c.accepts_marketing,
    c.customer_created_at,

    -- Lifetime metrics (zeros for never-purchased customers, of which there are
    -- none in this seed, but the coalesce is the production-correct posture).
    coalesce(o.lifetime_order_count,    0)                                     as lifetime_order_count,
    coalesce(o.lifetime_gross_subtotal, 0)                                     as lifetime_gross_revenue,
    coalesce(o.lifetime_net_subtotal,   0)                                     as lifetime_net_revenue,
    coalesce(o.lifetime_refund_amount,  0)                                     as lifetime_refund_amount,
    coalesce(o.average_order_value,     0)                                     as average_order_value,
    coalesce(o.is_repeat_customer,      false)                                 as is_repeat_customer,
    coalesce(o.repeat_order_count,      0)                                     as repeat_order_count,

    o.first_ordered_at,
    o.first_order_date,
    o.acquisition_source,
    o.acquisition_medium,
    o.acquisition_campaign,

    o.last_ordered_at,
    o.last_order_date

from customers c
left join orders_rollup o on c.customer_id = o.customer_id
left join countries     co on c.country_code = co.country_code
