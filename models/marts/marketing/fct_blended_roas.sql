{#
    Blended ROAS / MER (Marketing Efficiency Ratio) at the daily grain. The
    only honest top-line marketing metric for a D2C brand: total revenue (paid
    + organic + email + direct) divided by total paid spend. Insulated from
    attribution-window games. Operators target a "north-star" MER that funds
    overhead and growth.
#}

with daily_revenue as (

    select
        order_date                                          as date_day,
        sum(net_subtotal_after_refunds)                     as total_revenue,
        sum(contribution_margin)                            as total_contribution_margin,
        count(distinct order_id)                            as total_orders,
        count(distinct customer_id)                         as buying_customers
    from {{ ref('fct_orders') }}
    group by 1

),

daily_spend as (

    select
        date_day,
        sum(spend)                                          as total_spend,
        sum(impressions)                                    as total_impressions,
        sum(clicks)                                         as total_clicks
    from {{ ref('int_marketing__unified_spend') }}
    group by 1

),

calendar as (

    select date_day from {{ ref('dim_dates') }}
    where date_day between cast('{{ var("start_date") }}' as date)
                       and cast('{{ var("end_date") }}'   as date)

)

select
    cal.date_day,

    coalesce(s.total_spend, 0)                                            as total_spend,
    coalesce(s.total_impressions, 0)                                      as total_impressions,
    coalesce(s.total_clicks, 0)                                           as total_clicks,

    coalesce(r.total_revenue, 0)                                          as total_revenue,
    coalesce(r.total_contribution_margin, 0)                              as total_contribution_margin,
    coalesce(r.total_orders, 0)                                           as total_orders,

    case when coalesce(s.total_spend, 0) > 0
          then coalesce(r.total_revenue, 0) / s.total_spend
         else null
    end                                                                    as blended_roas,

    case when coalesce(s.total_spend, 0) > 0
          then coalesce(r.total_contribution_margin, 0) / s.total_spend
         else null
    end                                                                    as contribution_margin_mer

from calendar cal
left join daily_revenue r on cal.date_day = r.date_day
left join daily_spend   s on cal.date_day = s.date_day
