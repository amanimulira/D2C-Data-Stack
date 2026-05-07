{#
    Daily campaign-level performance. Joins paid spend to last-touch attributed
    revenue (via UTM match) and to platform-reported conversion value, so an
    operator can compare:

      • spend                              -- ground truth from ad platform
      • platform_reported_conversion_value -- platform self-attribution (high)
      • last_touch_revenue                 -- UTM-based last-touch (lower)

    The gap between the two attribution methods is itself a useful signal.
#}

with spend as (

    select * from {{ ref('int_marketing__unified_spend') }}

),

campaign_meta as (

    select campaign_id, campaign_name, utm_campaign, platform
    from {{ ref('stg_meta_ads__campaigns') }}

),

last_touch_revenue as (

    select
        o.order_date                                                 as date_day,
        o.utm_source                                                 as platform,
        o.utm_campaign                                               as utm_campaign,
        sum(o.net_subtotal_after_refunds)                            as last_touch_revenue,
        count(distinct o.order_id)                                   as last_touch_orders,
        count(distinct case when ch.first_order_date = o.order_date then o.customer_id end) as last_touch_new_customers
    from {{ ref('fct_orders') }} o
    left join {{ ref('int_customers__order_history') }} ch
           on o.customer_id = ch.customer_id
    group by 1, 2, 3

)

select
    s.date_day,
    s.platform,
    s.campaign_id,
    s.campaign_name,
    cm.utm_campaign,

    s.impressions,
    s.clicks,
    s.spend,
    s.reported_conversions                                            as platform_reported_conversions,
    s.reported_conversion_value                                       as platform_reported_revenue,

    coalesce(lt.last_touch_revenue, 0)                                as last_touch_revenue,
    coalesce(lt.last_touch_orders, 0)                                 as last_touch_orders,
    coalesce(lt.last_touch_new_customers, 0)                          as last_touch_new_customers,

    case when s.spend > 0 then s.reported_conversion_value / s.spend                  else 0 end as platform_reported_roas,
    case when s.spend > 0 then coalesce(lt.last_touch_revenue, 0)    / s.spend         else 0 end as last_touch_roas,
    case when s.spend > 0 and coalesce(lt.last_touch_new_customers, 0) > 0
          then s.spend / lt.last_touch_new_customers
         else null end                                                                            as cac_last_touch

from spend s
left join campaign_meta      cm on s.campaign_id = cm.campaign_id
left join last_touch_revenue lt
       on s.date_day      = lt.date_day
      and s.platform      = lt.platform
      and cm.utm_campaign = lt.utm_campaign
