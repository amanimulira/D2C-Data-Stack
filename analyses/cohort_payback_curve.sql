/*
    Cohort payback curve. For each acquisition cohort, computes cumulative
    contribution margin per acquired customer at month 0, 1, 2, ... and
    overlays it against blended CAC for that cohort. The crossover month is
    the cohort's payback period — a working-capital-critical KPI.

    Output (one row per cohort × month-since-acquisition):
        cohort_month, months_since_acquisition,
        cum_contribution_margin_per_customer,
        cohort_cac,
        payback_ratio  -- (cum margin / CAC) — payback = 1.0
*/

with cohort_size as (
    select
        cast(date_trunc('month', first_order_date) as date) as cohort_month,
        count(distinct customer_id)                          as cohort_customers
    from {{ ref('int_customers__order_history') }}
    group by 1
),

cohort_cac as (
    select
        cast(date_trunc('month', date_day) as date) as cohort_month,
        sum(spend)                                  as cohort_total_spend
    from {{ ref('int_marketing__unified_spend') }}
    group by 1
),

monthly_margin as (
    select
        cast(date_trunc('month', ch.first_order_date) as date)                    as cohort_month,
        ({{ dbt.datediff('ch.first_order_date', 'o.order_date', 'month') }}) as months_since_acquisition,
        sum(o.contribution_margin)                                                as period_margin
    from {{ ref('fct_orders') }} o
    join {{ ref('int_customers__order_history') }} ch on o.customer_id = ch.customer_id
    group by 1, 2
),

cumulative as (
    select
        cohort_month,
        months_since_acquisition,
        sum(period_margin) over (
            partition by cohort_month
            order by months_since_acquisition
            rows between unbounded preceding and current row
        ) as cum_margin
    from monthly_margin
)

select
    c.cohort_month,
    c.months_since_acquisition,
    cs.cohort_customers,

    c.cum_margin                                                                  as cum_contribution_margin,
    c.cum_margin / nullif(cs.cohort_customers, 0)                                 as cum_contribution_margin_per_customer,

    coalesce(cc.cohort_total_spend, 0)                                            as cohort_total_spend,
    coalesce(cc.cohort_total_spend, 0) / nullif(cs.cohort_customers, 0)           as cohort_cac,

    case
        when coalesce(cc.cohort_total_spend, 0) > 0 and cs.cohort_customers > 0
            then (c.cum_margin / cs.cohort_customers) / (cc.cohort_total_spend / cs.cohort_customers)
        else null
    end                                                                            as payback_ratio

from cumulative c
join cohort_size cs on c.cohort_month = cs.cohort_month
left join cohort_cac cc on c.cohort_month = cc.cohort_month
order by c.cohort_month, c.months_since_acquisition
