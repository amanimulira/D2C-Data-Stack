---
title: Customer Analytics
description: Cohort retention, LTV, and RFM lifecycle segments — the unit-economics view.
---

```sql customer_kpis
select
    count(*)                                                           as customers,
    count(case when is_repeat_customer then 1 end)                     as repeat_customers,
    count(case when is_repeat_customer then 1 end) * 1.0 / count(*)    as repeat_rate,
    avg(average_order_value)                                           as avg_aov,
    avg(lifetime_net_revenue)                                          as avg_ltv
from d2c_stack.dim_customers
```

<BigValue data={customer_kpis} value=customers title="Customers" fmt=num0 />
<BigValue data={customer_kpis} value=repeat_rate title="Repeat purchase rate" fmt=pct0 />
<BigValue data={customer_kpis} value=avg_aov title="Average Order Value" fmt=usd0 />
<BigValue data={customer_kpis} value=avg_ltv title="Avg Lifetime Net Revenue" fmt=usd0 />

## Cohort retention

```sql cohorts
select
    strftime(cohort_month, '%Y-%m')              as cohort,
    months_since_acquisition                      as month_n,
    cohort_customers,
    active_customers,
    retention_rate
from d2c_stack.customer_cohort_retention
order by cohort_month, months_since_acquisition
```

<DataTable data={cohorts} groupBy=cohort groupType=section subtotals=false>
    <Column id=month_n title="Month #" align=center />
    <Column id=cohort_customers title="Cohort size" align=right />
    <Column id=active_customers title="Active" align=right />
    <Column id=retention_rate title="Retention" fmt=pct0 align=right contentType=colorscale colorScale=positive />
</DataTable>

A healthy D2C cohort retention curve **plateaus** rather than zeroing out. Month-12 retention of 8–15% is normal for a $40 AOV consumable; under 5% means you're on a customer-acquisition treadmill.

## LTV by acquisition channel

```sql ltv_by_channel
select
    coalesce(c.acquisition_source, '(unknown)')   as acquisition_source,
    count(distinct c.customer_id)                  as customers,
    avg(l.ltv_revenue_total)                       as avg_ltv,
    avg(l.ltv_margin_total)                        as avg_margin_ltv
from d2c_stack.dim_customers c
join d2c_stack.customer_ltv l on c.customer_id = l.customer_id
group by 1
order by avg_ltv desc
```

<BarChart
    data={ltv_by_channel}
    x=acquisition_source
    y={["avg_ltv", "avg_margin_ltv"]}
    yFmt=usd0
    title="Average LTV by first-order acquisition channel"
    type=grouped
/>

The channel that buys the **highest-LTV customer** is rarely the cheapest. This chart is the most under-used decision tool in D2C — most operators optimize CAC by channel and miss that they're acquiring customers worth half as much.

## RFM lifecycle segments

```sql rfm
select
    rfm_segment,
    count(*)                          as customers,
    avg(monetary)                     as avg_monetary,
    avg(recency_days)                 as avg_recency_days
from d2c_stack.customer_rfm
group by rfm_segment
order by customers desc
```

<DataTable data={rfm}>
    <Column id=rfm_segment title="Segment" />
    <Column id=customers fmt=num0 align=right />
    <Column id=avg_monetary title="Avg lifetime $" fmt=usd0 align=right />
    <Column id=avg_recency_days title="Avg days since last order" fmt=num0 align=right />
</DataTable>

Each segment maps to a Klaviyo flow:

- **Champions** — VIP early access, no discount needed
- **Loyal** — referral programs, replenishment cadence
- **At Risk** — win-back with light discount + best-of email
- **Hibernating** — final reactivation, then suppress to control sender reputation

---

<small>Models behind this page: [`customer_cohort_retention`](https://github.com/amanimulira/D2C-Data-Stack/blob/main/models/marts/customer/customer_cohort_retention.sql) · [`customer_ltv`](https://github.com/amanimulira/D2C-Data-Stack/blob/main/models/marts/customer/customer_ltv.sql) · [`customer_rfm`](https://github.com/amanimulira/D2C-Data-Stack/blob/main/models/marts/customer/customer_rfm.sql)</small>
