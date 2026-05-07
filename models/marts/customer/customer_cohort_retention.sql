{#
    Monthly acquisition cohorts × months-since-first-order grid. The canonical
    "are we keeping the customers we acquire" report. Each row gives the count
    of cohort members that placed at least one order in month N after their
    cohort start (where N=0 is the acquisition month).
#}

with first_orders as (

    select
        customer_id,
        first_order_date,
        cast(date_trunc('month', first_order_date) as date)                  as cohort_month
    from {{ ref('int_customers__order_history') }}

),

orders as (

    select
        order_id,
        customer_id,
        order_date,
        cast(date_trunc('month', order_date) as date)                        as activity_month,
        net_subtotal_after_refunds
    from {{ ref('fct_orders') }}

),

cohort_size as (

    select
        cohort_month,
        count(distinct customer_id)                                          as cohort_customers
    from first_orders
    group by 1

),

activity as (

    select
        f.cohort_month,
        o.activity_month,
        ({{ dbt.datediff('f.cohort_month', 'o.activity_month', 'month') }})  as months_since_acquisition,
        count(distinct o.customer_id)                                              as active_customers,
        sum(o.net_subtotal_after_refunds)                                          as cohort_revenue,
        count(distinct o.order_id)                                                 as orders_in_period
    from first_orders f
    join orders o on f.customer_id = o.customer_id
    group by 1, 2, 3

)

select
    a.cohort_month,
    a.activity_month,
    a.months_since_acquisition,
    cs.cohort_customers,
    a.active_customers,
    a.cohort_revenue,
    a.orders_in_period,
    cast(a.active_customers as numeric) / nullif(cs.cohort_customers, 0)         as retention_rate

from activity a
join cohort_size cs on a.cohort_month = cs.cohort_month
order by a.cohort_month, a.months_since_acquisition
