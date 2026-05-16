"""Orders & Products — order graph, daily volume, product margin profile."""
from __future__ import annotations

import altair as alt
import streamlit as st

from lib.data import query
from lib.style import EXEC_PALETTE, apply_theme, section_caption

st.set_page_config(page_title="Orders • D2C Data Stack", page_icon="◆", layout="wide")
apply_theme()

st.markdown(
    "<div style='color:#64748B; font-size:0.8rem; text-transform:uppercase; "
    "letter-spacing:0.08em; font-weight:500;'>Orders</div>",
    unsafe_allow_html=True,
)
st.title("Orders & products")
st.markdown(
    "<p style='color:#475569; font-size:1rem; max-width:780px;'>"
    "The order graph — refund-net revenue, COGS, contribution margin, and "
    "per-SKU profitability.</p>",
    unsafe_allow_html=True,
)
st.markdown("---")

# ───────────────────────────────────────────────────────── KPIS
kpis = query(
    """
    select
        count(distinct order_id)                                              as orders,
        sum(net_subtotal_after_refunds)                                       as net_revenue,
        avg(order_subtotal)                                                   as aov,
        sum(refund_amount) / nullif(sum(order_subtotal), 0)                   as refund_rate,
        sum(contribution_margin) / nullif(sum(net_subtotal_after_refunds), 0) as cm_pct
    from marts_core.fct_orders
    """
).iloc[0]

st.markdown("### Order economics")
cols = st.columns(5)
cols[0].metric("Orders", f"{int(kpis.orders):,}")
cols[1].metric("Net revenue", f"${kpis.net_revenue:,.0f}")
cols[2].metric("AOV", f"${kpis.aov:,.0f}")
cols[3].metric("Refund rate", f"{kpis.refund_rate:.1%}")
cols[4].metric("Contribution margin %", f"{kpis.cm_pct:.0%}")

# ───────────────────────────────────────────────────────── DAILY VOLUME
st.markdown("## Daily order volume & AOV")

daily = query(
    """
    select
        order_date::date                              as date,
        count(*)                                       as orders,
        sum(net_subtotal_after_refunds)                as net_revenue,
        avg(order_subtotal)                            as aov
    from marts_core.fct_orders
    group by order_date
    order by order_date
    """
)

base = alt.Chart(daily).encode(x=alt.X("date:T", axis=alt.Axis(title=None, format="%b %d", tickCount=6)))
rev_line = base.mark_line(strokeWidth=1.8, color=EXEC_PALETTE[0]).encode(
    y=alt.Y("net_revenue:Q", axis=alt.Axis(title="Net revenue (USD)", format="$,.0f", titleColor=EXEC_PALETTE[0])),
    tooltip=[
        alt.Tooltip("date:T", title="Date"),
        alt.Tooltip("net_revenue:Q", title="Net revenue", format="$,.0f"),
        alt.Tooltip("orders:Q", title="Orders"),
        alt.Tooltip("aov:Q", title="AOV", format="$,.0f"),
    ],
)
aov_line = base.mark_line(strokeWidth=1.4, color=EXEC_PALETTE[3], strokeDash=[4, 3]).encode(
    y=alt.Y("aov:Q", axis=alt.Axis(title="AOV (USD)", format="$,.0f", titleColor=EXEC_PALETTE[3])),
)
st.altair_chart(
    alt.layer(rev_line, aov_line).resolve_scale(y="independent").properties(height=320),
    width="stretch",
)
section_caption(
    "Net revenue and AOV moving together = healthy growth. AOV falling while "
    "revenue rises = discount-driven volume that erodes margin."
)

# ───────────────────────────────────────────────────────── PRODUCT REVENUE
st.markdown("## Product revenue & margin")

products = query(
    """
    select
        p.product_title,
        p.product_type,
        sum(oi.quantity)                                  as units_sold,
        sum(oi.net_line_revenue)                          as net_revenue,
        sum(oi.line_gross_margin)                         as gross_margin,
        sum(oi.line_gross_margin) / nullif(sum(oi.net_line_revenue), 0) as margin_pct
    from marts_core.fct_order_items oi
    join marts_core.dim_products p on oi.product_id = p.product_id
    group by p.product_title, p.product_type
    order by net_revenue desc
    """
)

st.dataframe(
    products,
    width="stretch",
    hide_index=True,
    column_config={
        "product_title": st.column_config.TextColumn("Product"),
        "product_type": st.column_config.TextColumn("Type"),
        "units_sold": st.column_config.NumberColumn("Units", format="%d"),
        "net_revenue": st.column_config.NumberColumn("Net revenue", format="$%.0f"),
        "gross_margin": st.column_config.NumberColumn("Gross margin", format="$%.0f"),
        "margin_pct": st.column_config.NumberColumn("Margin %", format="%.0f%%"),
    },
)

# ───────────────────────────────────────────────────────── MARGIN PROFILE
st.markdown("## Margin profile by SKU")

margin = query(
    """
    select
        product_title,
        sum(net_line_revenue)         as net_revenue,
        sum(line_gross_margin)        as gross_margin
    from marts_core.fct_order_items
    group by product_title
    order by gross_margin desc
    """
)
margin["margin_pct"] = margin["gross_margin"] / margin["net_revenue"]
margin_long = margin.melt(
    id_vars=["product_title", "margin_pct"],
    value_vars=["net_revenue", "gross_margin"],
    var_name="metric",
    value_name="dollars",
)
margin_long["metric"] = margin_long["metric"].map(
    {"net_revenue": "Net revenue", "gross_margin": "Gross margin"}
)

margin_chart = (
    alt.Chart(margin_long)
    .mark_bar(cornerRadius=2)
    .encode(
        y=alt.Y("product_title:N", sort="-x", axis=alt.Axis(title=None, labelLimit=220)),
        x=alt.X("dollars:Q", axis=alt.Axis(title="USD", format="$,.0f")),
        color=alt.Color(
            "metric:N",
            scale=alt.Scale(range=[EXEC_PALETTE[2], EXEC_PALETTE[0]]),
            legend=alt.Legend(title=None, orient="top-left"),
        ),
        yOffset="metric:N",
        tooltip=[
            alt.Tooltip("product_title:N", title="Product"),
            alt.Tooltip("metric:N", title="Metric"),
            alt.Tooltip("dollars:Q", title="USD", format="$,.0f"),
            alt.Tooltip("margin_pct:Q", title="Margin %", format=".0%"),
        ],
    )
    .properties(height=max(220, 56 * margin["product_title"].nunique()))
)
st.altair_chart(margin_chart, width="stretch")
section_caption(
    "The gap between the two bars is per-SKU profitability. Re-running this "
    "view weekly catches creeping COGS — packaging cost increases, freight "
    "surcharges, supplier MOQ shifts — before they show up as a missed quarter."
)

# ───────────────────────────────────────────────────────── FOOTER
st.markdown("---")
st.caption(
    "Models behind this page: `fct_orders`, `fct_order_items`, `dim_products` — "
    "see [github.com/amanimulira/D2C-Data-Stack](https://github.com/amanimulira/D2C-Data-Stack)."
)
