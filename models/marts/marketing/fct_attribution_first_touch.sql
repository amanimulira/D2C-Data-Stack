{#
    First-touch attribution at the order grain. Each order is credited to the
    UTM source captured on the *customer's first order*. This answers "which
    channel acquired this customer?" — the key question for diagnosing where
    new revenue is being created.
#}

with orders as (

    select * from {{ ref('fct_orders') }}

),

acquisition as (

    select
        customer_id,
        acquisition_source,
        acquisition_medium,
        acquisition_campaign,
        first_order_date
    from {{ ref('int_customers__order_history') }}

)

select
    o.order_id,
    o.order_date,
    o.customer_id,
    a.first_order_date,
    case when o.order_date = a.first_order_date then true else false end       as is_first_order,

    a.acquisition_source                                                       as first_touch_source,
    a.acquisition_medium                                                       as first_touch_medium,
    a.acquisition_campaign                                                     as first_touch_campaign,

    o.net_subtotal_after_refunds                                               as attributed_revenue,
    o.contribution_margin                                                      as attributed_contribution_margin

from orders o
join acquisition a on o.customer_id = a.customer_id
