---
title: Orders & Products
description: Order volume, AOV, refund rate, and product-mix economics.
---

```sql order_kpis
select
    count(distinct order_id)                                           as orders,
    sum(net_subtotal_after_refunds)                                    as net_revenue,
    avg(order_subtotal)                                                as aov,
    sum(refund_amount) / nullif(sum(order_subtotal), 0)                as refund_rate,
    sum(contribution_margin) / nullif(sum(net_subtotal_after_refunds), 0) as cm_pct
from d2c_stack.fct_orders
```

<BigValue data={order_kpis} value=orders title="Orders" fmt=num0 />
<BigValue data={order_kpis} value=net_revenue title="Net Revenue" fmt=usd0 />
<BigValue data={order_kpis} value=aov title="AOV" fmt=usd0 />
<BigValue data={order_kpis} value=refund_rate title="Refund rate" fmt=pct1 />
<BigValue data={order_kpis} value=cm_pct title="Contribution margin %" fmt=pct0 />

## Daily order volume

```sql daily_orders
select
    order_date,
    count(*)                                       as orders,
    sum(net_subtotal_after_refunds)                as net_revenue,
    avg(order_subtotal)                            as aov
from d2c_stack.fct_orders
group by order_date
order by order_date
```

<LineChart
    data={daily_orders}
    x=order_date
    y=net_revenue
    yFmt=usd0
    title="Daily net revenue"
/>

<BarChart
    data={daily_orders}
    x=order_date
    y=orders
    title="Daily order count"
/>

## Top products by revenue

```sql products_rev
select
    p.product_title,
    p.product_type,
    sum(oi.quantity)                                  as units_sold,
    sum(oi.net_line_revenue)                          as net_revenue,
    sum(oi.line_gross_margin)                         as gross_margin,
    sum(oi.line_gross_margin) / nullif(sum(oi.net_line_revenue), 0) as margin_pct
from d2c_stack.fct_order_items oi
join d2c_stack.dim_products p on oi.product_id = p.product_id
group by p.product_title, p.product_type
order by net_revenue desc
```

<DataTable data={products_rev} totalRow=true>
    <Column id=product_title title="Product" />
    <Column id=product_type title="Type" />
    <Column id=units_sold fmt=num0 align=right />
    <Column id=net_revenue fmt=usd0 align=right />
    <Column id=gross_margin fmt=usd0 align=right />
    <Column id=margin_pct title="Margin %" fmt=pct0 align=right contentType=colorscale colorScale=positive />
</DataTable>

## Margin profile

```sql margin_dist
select
    product_title,
    sum(net_line_revenue)         as net_revenue,
    sum(line_gross_margin)        as gross_margin
from d2c_stack.fct_order_items
group by product_title
order by gross_margin desc
```

<BarChart
    data={margin_dist}
    x=product_title
    y={["net_revenue", "gross_margin"]}
    yFmt=usd0
    title="Net revenue vs gross margin by SKU"
    type=grouped
    swapXY=true
/>

The gap between the two bars is your **per-SKU profitability**. Re-running this view weekly catches creeping COGS — packaging cost increases, freight surcharges, supplier MOQ shifts — before they show up as a missed quarter.

---

<small>Models behind this page: [`fct_orders`](https://github.com/amanimulira/D2C-Data-Stack/blob/main/models/marts/core/fct_orders.sql) · [`fct_order_items`](https://github.com/amanimulira/D2C-Data-Stack/blob/main/models/marts/core/fct_order_items.sql) · [`dim_products`](https://github.com/amanimulira/D2C-Data-Stack/blob/main/models/marts/core/dim_products.sql)</small>
