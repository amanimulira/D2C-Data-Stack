"""Executive summary page — the one screenshot you'd put in a board deck."""
from __future__ import annotations

import altair as alt
import streamlit as st

from lib.data import query
from lib.style import EXEC_PALETTE, apply_theme, section_caption

st.set_page_config(
    page_title="Modern D2C Data Stack",
    page_icon="◆",
    layout="wide",
    initial_sidebar_state="expanded",
)
apply_theme()

# ───────────────────────────────────────────────────────── HEADER
st.markdown(
    "<div style='color:#64748B; font-size:0.8rem; text-transform:uppercase; "
    "letter-spacing:0.08em; font-weight:500;'>Reference implementation</div>",
    unsafe_allow_html=True,
)
st.title("Modern D2C Data Stack")
st.markdown(
    "<p style='color:#475569; font-size:1.05rem; max-width:760px; margin-top:-0.25rem;'>"
    "Every chart on every page is one SQL query against a documented, tested mart "
    "produced by the <code>dbt</code> project in this repo. Nothing pre-aggregated, "
    "nothing hidden.</p>",
    unsafe_allow_html=True,
)
st.markdown("---")

# ───────────────────────────────────────────────────────── HEADLINE KPIS
kpis = query(
    """
    select
        sum(net_subtotal_after_refunds)                                  as net_revenue,
        sum(contribution_margin)                                         as contribution_margin,
        sum(contribution_margin) / nullif(sum(net_subtotal_after_refunds), 0) as cm_pct,
        count(distinct order_id)                                         as orders,
        count(distinct customer_id)                                      as customers,
        avg(order_subtotal)                                              as aov
    from marts_core.fct_orders
    """
).iloc[0]

spend = query("select sum(spend) as total_spend from marts_marketing.fct_marketing_performance").iloc[0]

blended = query(
    """
    select
        sum(total_revenue)                                  as total_revenue,
        sum(total_spend)                                    as total_spend,
        sum(total_revenue) / nullif(sum(total_spend), 0)    as blended_roas,
        sum(total_contribution_margin) / nullif(sum(total_spend), 0) as cm_mer
    from marts_marketing.fct_blended_roas
    """
).iloc[0]

st.markdown("### Headline metrics")

row1 = st.columns(3)
row1[0].metric("Net revenue", f"${kpis.net_revenue:,.0f}")
row1[1].metric("Contribution margin", f"${kpis.contribution_margin:,.0f}", f"{kpis.cm_pct:.0%} of net revenue")
row1[2].metric("Blended ROAS / MER", f"{blended.blended_roas:.2f}x", f"CM-MER {blended.cm_mer:.2f}x")

row2 = st.columns(3)
row2[0].metric("Orders", f"{int(kpis.orders):,}")
row2[1].metric("Active customers", f"{int(kpis.customers):,}", f"AOV ${kpis.aov:,.0f}")
row2[2].metric("Paid spend", f"${spend.total_spend:,.0f}")

section_caption(
    "Blended ROAS (MER) divides total revenue by total paid spend — the only "
    "channel-attribution-proof view of marketing efficiency."
)

# ───────────────────────────────────────────────────────── DAILY TREND
st.markdown("## Daily revenue vs paid spend")

daily = query(
    """
    select
        date_day::date                       as date,
        total_revenue,
        total_spend,
        total_contribution_margin,
        blended_roas
    from marts_marketing.fct_blended_roas
    where total_revenue > 0 or total_spend > 0
    order by date_day
    """
)
daily_long = daily.melt(
    id_vars=["date"],
    value_vars=["total_revenue", "total_spend"],
    var_name="series",
    value_name="dollars",
)
daily_long["series"] = daily_long["series"].map(
    {"total_revenue": "Revenue", "total_spend": "Paid spend"}
)

revenue_spend_chart = (
    alt.Chart(daily_long)
    .mark_line(strokeWidth=1.8, interpolate="monotone")
    .encode(
        x=alt.X("date:T", axis=alt.Axis(title=None, format="%b %d", tickCount=6)),
        y=alt.Y("dollars:Q", axis=alt.Axis(title="USD", format="$,.0f")),
        color=alt.Color(
            "series:N",
            scale=alt.Scale(domain=["Revenue", "Paid spend"], range=[EXEC_PALETTE[0], EXEC_PALETTE[3]]),
            legend=alt.Legend(title=None, orient="top-left"),
        ),
        tooltip=[
            alt.Tooltip("date:T", title="Date"),
            alt.Tooltip("series:N", title="Series"),
            alt.Tooltip("dollars:Q", title="USD", format="$,.0f"),
        ],
    )
    .properties(height=320)
)
st.altair_chart(revenue_spend_chart, width="stretch")
section_caption(
    "A widening gap between revenue and spend signals improving efficiency; "
    "a converging gap means CAC is climbing faster than AOV."
)

# ───────────────────────────────────────────────────────── CHANNEL SPLIT
st.markdown("## Where revenue comes from (last-touch)")

channel = query(
    """
    select
        coalesce(last_touch_source, '(direct)') as source,
        sum(attributed_revenue)                  as revenue,
        count(distinct order_id)                 as orders
    from marts_marketing.fct_attribution_last_touch
    group by last_touch_source
    order by revenue desc
    """
)

channel_chart = (
    alt.Chart(channel)
    .mark_bar(cornerRadius=2)
    .encode(
        y=alt.Y("source:N", sort="-x", axis=alt.Axis(title=None, labelLimit=160)),
        x=alt.X("revenue:Q", axis=alt.Axis(title="Last-touch revenue (USD)", format="$,.0f")),
        color=alt.value(EXEC_PALETTE[0]),
        tooltip=[
            alt.Tooltip("source:N", title="Source"),
            alt.Tooltip("revenue:Q", title="Revenue", format="$,.0f"),
            alt.Tooltip("orders:Q", title="Orders", format=",.0f"),
        ],
    )
    .properties(height=max(180, 32 * len(channel)))
)
st.altair_chart(channel_chart, width="stretch")
section_caption(
    "Last-touch credits each order to its own UTM. Compare with the first-touch "
    "(acquisition) view on the Marketing page — the two never tell the same story."
)

# ───────────────────────────────────────────────────────── NAV
st.markdown("---")
st.markdown(
    "<div style='color:#475569;'>Use the sidebar to navigate to the "
    "<b>Marketing</b>, <b>Customers</b>, and <b>Orders</b> deep-dives.</div>",
    unsafe_allow_html=True,
)
