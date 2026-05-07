/*
    Monthly Business Review. Drop-in query for Looker, Lightdash, Metabase or
    a Snowflake worksheet — produces the headline numbers a D2C operator wants
    in front of them every Monday morning.

    Output (one row per month):
        month, gross_revenue, net_revenue, contribution_margin, orders,
        new_customers, repeat_orders, aov, ad_spend, blended_roas

    Run as:
        dbt compile --select analyses/monthly_business_review.sql
        # then copy the compiled SQL out of target/compiled/...
*/

with months as (
    select distinct cast(date_trunc('month', date_day) as date) as month_start_date
    from {{ ref('dim_dates') }}
),

revenue as (
    select
        cast(date_trunc('month', order_date) as date)             as month_start_date,
        sum(order_subtotal)                                       as gross_revenue,
        sum(net_subtotal_after_refunds)                           as net_revenue,
        sum(contribution_margin)                                  as contribution_margin,
        count(distinct order_id)                                  as orders,
        avg(order_subtotal)                                       as aov
    from {{ ref('fct_orders') }}
    group by 1
),

new_customers as (
    select
        cast(date_trunc('month', first_order_date) as date)       as month_start_date,
        count(distinct customer_id)                               as new_customers
    from {{ ref('int_customers__order_history') }}
    group by 1
),

repeats as (
    select
        cast(date_trunc('month', o.order_date) as date)           as month_start_date,
        count(distinct case when ch.first_order_date < o.order_date then o.order_id end) as repeat_orders
    from {{ ref('fct_orders') }} o
    join {{ ref('int_customers__order_history') }} ch on o.customer_id = ch.customer_id
    group by 1
),

spend as (
    select
        cast(date_trunc('month', date_day) as date)               as month_start_date,
        sum(spend)                                                as ad_spend
    from {{ ref('int_marketing__unified_spend') }}
    group by 1
)

select
    m.month_start_date,
    coalesce(r.gross_revenue,           0)                        as gross_revenue,
    coalesce(r.net_revenue,             0)                        as net_revenue,
    coalesce(r.contribution_margin,     0)                        as contribution_margin,
    coalesce(r.orders,                  0)                        as orders,
    coalesce(nc.new_customers,          0)                        as new_customers,
    coalesce(rp.repeat_orders,          0)                        as repeat_orders,
    coalesce(r.aov,                     0)                        as aov,
    coalesce(s.ad_spend,                0)                        as ad_spend,
    case when coalesce(s.ad_spend, 0) > 0
         then coalesce(r.net_revenue, 0) / s.ad_spend
         else null
    end                                                            as blended_roas

from months m
left join revenue       r  on m.month_start_date = r.month_start_date
left join new_customers nc on m.month_start_date = nc.month_start_date
left join repeats       rp on m.month_start_date = rp.month_start_date
left join spend         s  on m.month_start_date = s.month_start_date
where r.orders is not null
order by m.month_start_date
