---
title: Marketing Performance
description: Channel-level ROAS with platform-reported and last-touch attribution side-by-side.
---

The hardest question in D2C marketing is also the simplest: **how much did we make for every dollar we spent?** Three views, three answers — none of them the same.

```sql totals
select
    sum(spend)                                                         as total_spend,
    sum(platform_reported_revenue)                                     as platform_reported_revenue,
    sum(last_touch_revenue)                                            as last_touch_revenue,
    sum(platform_reported_revenue) / nullif(sum(spend), 0)             as platform_reported_roas,
    sum(last_touch_revenue) / nullif(sum(spend), 0)                    as last_touch_roas
from d2c_stack.fct_marketing_performance
```

```sql blended_total
select
    sum(total_revenue) / nullif(sum(total_spend), 0) as blended_roas
from d2c_stack.fct_blended_roas
```

<BigValue data={totals} value=total_spend title="Paid Spend" fmt=usd0 />
<BigValue data={totals} value=platform_reported_roas title="Platform-reported ROAS" fmt=num1 />
<BigValue data={totals} value=last_touch_roas title="Last-touch ROAS (UTM)" fmt=num1 />
<BigValue data={blended_total} value=blended_roas title="Blended ROAS / MER" fmt=num1 />

The gap between platform-reported and last-touch ROAS is the **attribution overhang** — view-through and 7-day-click conversions Meta credits to itself that may or may not have been incremental. Blended ROAS is robust to this — it's the number to give a CFO.

## Daily blended ROAS

```sql daily_roas
select
    date_day,
    total_revenue,
    total_spend,
    blended_roas,
    contribution_margin_mer
from d2c_stack.fct_blended_roas
where total_spend > 0
order by date_day
```

<LineChart
    data={daily_roas}
    x=date_day
    y={["blended_roas", "contribution_margin_mer"]}
    yFmt=num1
    title="Blended ROAS vs Contribution-Margin MER"
    yAxisTitle="Multiple of spend"
/>

A revenue MER of 4.0 on 70% margin is **not** the same business as 4.0 on 25% margin. The gap between the two lines is your real margin profile.

## Spend by campaign

```sql by_campaign
select
    campaign_name,
    sum(spend)                                                         as spend,
    sum(impressions)                                                   as impressions,
    sum(clicks)                                                        as clicks,
    sum(spend) / nullif(sum(clicks), 0)                                as cpc,
    sum(platform_reported_revenue)                                     as platform_revenue,
    sum(last_touch_revenue)                                            as last_touch_revenue,
    sum(platform_reported_revenue) / nullif(sum(spend), 0)             as platform_roas,
    sum(last_touch_revenue) / nullif(sum(spend), 0)                    as last_touch_roas
from d2c_stack.fct_marketing_performance
group by campaign_name
order by spend desc
```

<DataTable data={by_campaign} totalRow=true>
    <Column id=campaign_name title="Campaign" />
    <Column id=spend fmt=usd0 align=right />
    <Column id=impressions fmt=num0 align=right />
    <Column id=clicks fmt=num0 align=right />
    <Column id=cpc title="CPC" fmt=usd2 align=right />
    <Column id=platform_revenue title="Platform Rev" fmt=usd0 align=right />
    <Column id=last_touch_revenue title="UTM Rev" fmt=usd0 align=right />
    <Column id=platform_roas title="Platform ROAS" fmt=num1 align=right contentType=delta deltaSymbol=false />
    <Column id=last_touch_roas title="UTM ROAS" fmt=num1 align=right contentType=delta deltaSymbol=false />
</DataTable>

## Spend ramp

```sql monthly_spend
select
    date_trunc('month', date_day)         as month,
    campaign_name,
    sum(spend)                             as spend
from d2c_stack.fct_marketing_performance
group by 1, 2
order by month, spend desc
```

<BarChart
    data={monthly_spend}
    x=month
    y=spend
    series=campaign_name
    type=stacked
    yFmt=usd0
    title="Monthly paid spend by campaign"
/>

---

<small>Models behind this page: [`fct_marketing_performance`](https://github.com/amanimulira/D2C-Data-Stack/blob/main/models/marts/marketing/fct_marketing_performance.sql) · [`fct_blended_roas`](https://github.com/amanimulira/D2C-Data-Stack/blob/main/models/marts/marketing/fct_blended_roas.sql)</small>
