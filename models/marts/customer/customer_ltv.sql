{#
    Per-customer lifetime-value table. One row per customer with cumulative
    revenue at 30/60/90/180/365-day windows after their first order. This is
    the input for cohort LTV charts and the contribution-margin CAC view.
#}

with customers as (

    select customer_id, first_order_date
    from {{ ref('int_customers__order_history') }}

),

orders as (

    select
        customer_id,
        order_date,
        net_subtotal_after_refunds,
        contribution_margin
    from {{ ref('fct_orders') }}

),

joined as (

    select
        c.customer_id,
        c.first_order_date,
        o.order_date,
        {{ dbt.datediff('c.first_order_date', 'o.order_date', 'day') }}  as days_from_acquisition,
        o.net_subtotal_after_refunds,
        o.contribution_margin
    from customers c
    join orders    o on c.customer_id = o.customer_id

),

windowed as (

    select
        customer_id,
        first_order_date,
        sum(net_subtotal_after_refunds)                                                                 as ltv_revenue_total,
        sum(contribution_margin)                                                                        as ltv_margin_total,
        sum(case when days_from_acquisition <= 30  then net_subtotal_after_refunds else 0 end)          as ltv_revenue_30d,
        sum(case when days_from_acquisition <= 60  then net_subtotal_after_refunds else 0 end)          as ltv_revenue_60d,
        sum(case when days_from_acquisition <= 90  then net_subtotal_after_refunds else 0 end)          as ltv_revenue_90d,
        sum(case when days_from_acquisition <= 180 then net_subtotal_after_refunds else 0 end)          as ltv_revenue_180d,
        sum(case when days_from_acquisition <= 365 then net_subtotal_after_refunds else 0 end)          as ltv_revenue_365d,
        sum(case when days_from_acquisition <= 90  then contribution_margin        else 0 end)          as ltv_margin_90d,
        sum(case when days_from_acquisition <= 365 then contribution_margin        else 0 end)          as ltv_margin_365d
    from joined
    group by 1, 2

)

select * from windowed
