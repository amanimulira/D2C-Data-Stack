---
title: Modern D2C Data Stack — Live Demo
description: Dashboard built directly on the dbt project's marts. Powered by Evidence + DuckDB.
---

This dashboard reads directly from `marts_*` schemas produced by the [`D2C-Data-Stack`](https://github.com/amanimulira/D2C-Data-Stack) dbt project. Every chart on every page is one SQL query against a documented, tested mart — nothing pre-aggregated, nothing hidden.

```sql kpis
select
    sum(net_subtotal_after_refunds)            as net_revenue,
    sum(contribution_margin)                   as contribution_margin,
    sum(order_subtotal) - sum(net_subtotal_after_refunds) as refund_amount,
    count(distinct order_id)                   as orders,
    count(distinct customer_id)                as customers,
    avg(order_subtotal)                        as aov
from d2c_stack.fct_orders
```

```sql spend_kpi
select
    sum(spend) as total_spend
from d2c_stack.fct_marketing_performance
```

```sql blended
select
    sum(total_revenue)                                   as total_revenue,
    sum(total_spend)                                     as total_spend,
    sum(total_revenue) / nullif(sum(total_spend), 0)     as blended_roas,
    sum(total_contribution_margin) / nullif(sum(total_spend), 0) as cm_mer
from d2c_stack.fct_blended_roas
```

<BigValue data={kpis} value=net_revenue title="Net Revenue" fmt=usd0 />
<BigValue data={kpis} value=contribution_margin title="Contribution Margin" fmt=usd0 />
<BigValue data={blended} value=blended_roas title="Blended ROAS" fmt=num1 />
<BigValue data={kpis} value=customers title="Active Customers" fmt=num0 />
<BigValue data={kpis} value=orders title="Orders" fmt=num0 />
<BigValue data={spend_kpi} value=total_spend title="Paid Spend" fmt=usd0 />

## Daily revenue and spend

```sql daily
select
    date_day,
    total_revenue,
    total_spend,
    total_contribution_margin,
    blended_roas
from d2c_stack.fct_blended_roas
where total_revenue > 0 or total_spend > 0
order by date_day
```

<LineChart
    data={daily}
    x=date_day
    y={["total_revenue", "total_spend"]}
    yFmt=usd0
    title="Daily revenue vs paid spend"
    yAxisTitle="USD"
/>

<LineChart
    data={daily}
    x=date_day
    y=blended_roas
    yFmt=num1
    title="Daily blended ROAS"
    yAxisTitle="ROAS"
/>

## Where revenue comes from (last-touch)

```sql channel_split
select
    last_touch_source,
    sum(attributed_revenue)               as revenue,
    count(distinct order_id)              as orders
from d2c_stack.fct_attribution_last_touch
group by last_touch_source
order by revenue desc
```

<BarChart
    data={channel_split}
    x=last_touch_source
    y=revenue
    yFmt=usd0
    title="Revenue by last-touch channel"
    swapXY=true
/>

## Explore

- [**Marketing performance**](/marketing) — channel ROAS, last-touch vs platform-reported, campaign efficiency
- [**Customer analytics**](/customers) — cohort retention, LTV, RFM lifecycle segments
- [**Orders & products**](/orders) — order volume, AOV, top SKUs by revenue and margin

---

<small>Data is synthetic (10 customers · 30 orders · 90 days). Built from the [`D2C-Data-Stack`](https://github.com/amanimulira/D2C-Data-Stack) dbt project. Every metric definition lives in [`docs/business_metrics.md`](https://github.com/amanimulira/D2C-Data-Stack/blob/main/docs/business_metrics.md).</small>
