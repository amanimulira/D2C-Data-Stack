"""Customer Analytics — cohorts, LTV, RFM."""
from __future__ import annotations

import altair as alt
import streamlit as st

from lib.data import query
from lib.style import EXEC_PALETTE, apply_theme, section_caption

st.set_page_config(page_title="Customers • D2C Data Stack", page_icon="◆", layout="wide")
apply_theme()

st.markdown(
    "<div style='color:#64748B; font-size:0.8rem; text-transform:uppercase; "
    "letter-spacing:0.08em; font-weight:500;'>Customers</div>",
    unsafe_allow_html=True,
)
st.title("Customer analytics")
st.markdown(
    "<p style='color:#475569; font-size:1rem; max-width:780px;'>"
    "Cohort retention, lifetime value, and lifecycle segmentation — the "
    "unit-economics view of the business.</p>",
    unsafe_allow_html=True,
)
st.markdown("---")

# ───────────────────────────────────────────────────────── KPIS
kpis = query(
    """
    select
        count(*)                                                           as customers,
        count(case when is_repeat_customer then 1 end)                     as repeat_customers,
        count(case when is_repeat_customer then 1 end) * 1.0 / count(*)    as repeat_rate,
        avg(average_order_value)                                           as avg_aov,
        avg(lifetime_net_revenue)                                          as avg_ltv
    from marts_core.dim_customers
    """
).iloc[0]

st.markdown("### Customer base")
cols = st.columns(4)
cols[0].metric("Customers", f"{int(kpis.customers):,}")
cols[1].metric("Repeat purchase rate", f"{kpis.repeat_rate:.0%}")
cols[2].metric("Average AOV", f"${kpis.avg_aov:,.0f}")
cols[3].metric("Avg lifetime net revenue", f"${kpis.avg_ltv:,.0f}")

# ───────────────────────────────────────────────────────── COHORT HEATMAP
st.markdown("## Cohort retention")

cohorts = query(
    """
    select
        strftime(cohort_month, '%Y-%m')              as cohort,
        months_since_acquisition                      as month_n,
        cohort_customers,
        active_customers,
        retention_rate
    from marts_customer.customer_cohort_retention
    order by cohort_month, months_since_acquisition
    """
)

heatmap = (
    alt.Chart(cohorts)
    .mark_rect(stroke="#FFFFFF", strokeWidth=2)
    .encode(
        x=alt.X(
            "month_n:O",
            axis=alt.Axis(title="Months since acquisition", labelAngle=0, titlePadding=14),
        ),
        y=alt.Y("cohort:O", axis=alt.Axis(title="Cohort", titlePadding=14)),
        color=alt.Color(
            "retention_rate:Q",
            scale=alt.Scale(scheme="blues", domain=[0, 1]),
            legend=alt.Legend(title="Retention", format=".0%", orient="right"),
        ),
        tooltip=[
            alt.Tooltip("cohort:N", title="Cohort"),
            alt.Tooltip("month_n:Q", title="Month #"),
            alt.Tooltip("cohort_customers:Q", title="Cohort size"),
            alt.Tooltip("active_customers:Q", title="Active"),
            alt.Tooltip("retention_rate:Q", title="Retention", format=".1%"),
        ],
    )
    .properties(height=max(180, 36 * cohorts["cohort"].nunique()))
)
text = (
    alt.Chart(cohorts)
    .mark_text(fontSize=10, fontWeight=500)
    .encode(
        x="month_n:O",
        y="cohort:O",
        text=alt.Text("retention_rate:Q", format=".0%"),
        color=alt.condition(
            alt.datum.retention_rate > 0.4, alt.value("white"), alt.value("#0F172A")
        ),
    )
)
st.altair_chart(heatmap + text, width="stretch")
section_caption(
    "A healthy D2C cohort plateaus rather than zeroing out. Month-12 retention "
    "of 8–15% is normal for a $40 AOV consumable; under 5% means you're on an "
    "acquisition treadmill."
)

# ───────────────────────────────────────────────────────── LTV BY CHANNEL
st.markdown("## LTV by acquisition channel")

ltv = query(
    """
    select
        coalesce(c.acquisition_source, '(unknown)')   as acquisition_source,
        count(distinct c.customer_id)                  as customers,
        avg(l.ltv_revenue_total)                       as avg_ltv,
        avg(l.ltv_margin_total)                        as avg_margin_ltv
    from marts_core.dim_customers c
    join marts_customer.customer_ltv l on c.customer_id = l.customer_id
    group by 1
    order by avg_ltv desc
    """
)
ltv_long = ltv.melt(
    id_vars=["acquisition_source", "customers"],
    value_vars=["avg_ltv", "avg_margin_ltv"],
    var_name="metric",
    value_name="dollars",
)
ltv_long["metric"] = ltv_long["metric"].map(
    {"avg_ltv": "Avg LTV (revenue)", "avg_margin_ltv": "Avg LTV (margin)"}
)

ltv_chart = (
    alt.Chart(ltv_long)
    .mark_bar(cornerRadius=2)
    .encode(
        x=alt.X("acquisition_source:N", axis=alt.Axis(title=None, labelAngle=-20)),
        y=alt.Y("dollars:Q", axis=alt.Axis(title="USD", format="$,.0f")),
        color=alt.Color(
            "metric:N",
            scale=alt.Scale(range=[EXEC_PALETTE[0], EXEC_PALETTE[3]]),
            legend=alt.Legend(title=None, orient="top-left"),
        ),
        xOffset="metric:N",
        tooltip=[
            alt.Tooltip("acquisition_source:N", title="Channel"),
            alt.Tooltip("metric:N", title="Metric"),
            alt.Tooltip("dollars:Q", title="USD", format="$,.0f"),
        ],
    )
    .properties(height=340)
)
st.altair_chart(ltv_chart, width="stretch")
section_caption(
    "The channel that buys the highest-LTV customer is rarely the cheapest. "
    "Most operators optimize CAC by channel and miss that they're acquiring "
    "customers worth half as much."
)

# ───────────────────────────────────────────────────────── RFM
st.markdown("## RFM lifecycle segments")

rfm = query(
    """
    select
        rfm_segment,
        count(*)                          as customers,
        avg(monetary)                     as avg_monetary,
        avg(recency_days)                 as avg_recency_days
    from marts_customer.customer_rfm
    group by rfm_segment
    order by customers desc
    """
)

rfm_chart = (
    alt.Chart(rfm)
    .mark_bar(cornerRadius=2)
    .encode(
        y=alt.Y("rfm_segment:N", sort="-x", axis=alt.Axis(title=None, labelLimit=200)),
        x=alt.X("customers:Q", axis=alt.Axis(title="Customers", format=",.0f")),
        color=alt.value(EXEC_PALETTE[0]),
        tooltip=[
            alt.Tooltip("rfm_segment:N", title="Segment"),
            alt.Tooltip("customers:Q", title="Customers", format=",.0f"),
            alt.Tooltip("avg_monetary:Q", title="Avg lifetime $", format="$,.0f"),
            alt.Tooltip("avg_recency_days:Q", title="Avg days since last order", format=",.0f"),
        ],
    )
    .properties(height=max(180, 36 * len(rfm)))
)
st.altair_chart(rfm_chart, width="stretch")

st.markdown(
    """
    **Each segment maps to a Klaviyo flow:**

    - **Champions** — VIP early access, no discount needed
    - **Loyal** — referral programs, replenishment cadence
    - **At Risk** — win-back with light discount + best-of email
    - **Hibernating** — final reactivation, then suppress to control sender reputation
    """
)

# ───────────────────────────────────────────────────────── FOOTER
st.markdown("---")
st.caption(
    "Models behind this page: `customer_cohort_retention`, `customer_ltv`, "
    "`customer_rfm` — see "
    "[github.com/amanimulira/D2C-Data-Stack](https://github.com/amanimulira/D2C-Data-Stack)."
)
