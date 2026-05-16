"""Marketing Performance — three views of ROAS, side by side."""
from __future__ import annotations

import altair as alt
import streamlit as st

from lib.data import query
from lib.style import EXEC_PALETTE, apply_theme, section_caption

st.set_page_config(page_title="Marketing • D2C Data Stack", page_icon="◆", layout="wide")
apply_theme()

st.markdown(
    "<div style='color:#64748B; font-size:0.8rem; text-transform:uppercase; "
    "letter-spacing:0.08em; font-weight:500;'>Marketing</div>",
    unsafe_allow_html=True,
)
st.title("Marketing performance")
st.markdown(
    "<p style='color:#475569; font-size:1rem; max-width:780px;'>"
    "The hardest question in D2C marketing is also the simplest: "
    "<em>how much did we make for every dollar we spent?</em> "
    "Three views, three answers — and none of them should agree.</p>",
    unsafe_allow_html=True,
)
st.markdown("---")

# ───────────────────────────────────────────────────────── ROAS COMPARISON
totals = query(
    """
    select
        sum(spend)                                                       as total_spend,
        sum(platform_reported_revenue)                                   as platform_revenue,
        sum(last_touch_revenue)                                          as last_touch_revenue,
        sum(platform_reported_revenue) / nullif(sum(spend), 0)           as platform_roas,
        sum(last_touch_revenue) / nullif(sum(spend), 0)                  as last_touch_roas
    from marts_marketing.fct_marketing_performance
    """
).iloc[0]
blended = query(
    """
    select sum(total_revenue) / nullif(sum(total_spend), 0) as blended_roas
    from marts_marketing.fct_blended_roas
    """
).iloc[0]

st.markdown("### The three ROAS numbers")

cols = st.columns(4)
cols[0].metric("Paid spend", f"${totals.total_spend:,.0f}")
cols[1].metric("Platform-reported ROAS", f"{totals.platform_roas:.2f}x")
cols[2].metric("Last-touch ROAS (UTM)", f"{totals.last_touch_roas:.2f}x")
cols[3].metric("Blended ROAS / MER", f"{blended.blended_roas:.2f}x")

section_caption(
    "The gap between platform-reported and last-touch ROAS is the attribution "
    "overhang — view-through and 7-day-click conversions Meta credits to itself. "
    "Blended ROAS is robust to it: it's the number for the CFO."
)

# ───────────────────────────────────────────────────────── DAILY BLENDED
st.markdown("## Daily blended ROAS vs CM-MER")

daily = query(
    """
    select
        date_day::date as date,
        total_revenue,
        total_spend,
        blended_roas,
        contribution_margin_mer
    from marts_marketing.fct_blended_roas
    where total_spend > 0
    order by date_day
    """
)
daily_long = daily.melt(
    id_vars=["date"],
    value_vars=["blended_roas", "contribution_margin_mer"],
    var_name="metric",
    value_name="multiple",
)
daily_long["metric"] = daily_long["metric"].map(
    {"blended_roas": "Blended ROAS", "contribution_margin_mer": "Contribution-margin MER"}
)

roas_chart = (
    alt.Chart(daily_long)
    .mark_line(strokeWidth=1.8, interpolate="monotone")
    .encode(
        x=alt.X("date:T", axis=alt.Axis(title=None, format="%b %d", tickCount=6)),
        y=alt.Y("multiple:Q", axis=alt.Axis(title="Multiple of paid spend", format=",.1f")),
        color=alt.Color(
            "metric:N",
            scale=alt.Scale(
                domain=["Blended ROAS", "Contribution-margin MER"],
                range=[EXEC_PALETTE[0], EXEC_PALETTE[3]],
            ),
            legend=alt.Legend(title=None, orient="top-left"),
        ),
        tooltip=[
            alt.Tooltip("date:T", title="Date"),
            alt.Tooltip("metric:N", title="Metric"),
            alt.Tooltip("multiple:Q", title="Multiple", format=",.2f"),
        ],
    )
    .properties(height=320)
)
st.altair_chart(roas_chart, width="stretch")
section_caption(
    "A revenue MER of 4.0 on 70% margin is not the same business as 4.0 on 25% "
    "margin. The gap between the two lines is your real margin profile."
)

# ───────────────────────────────────────────────────────── BY CAMPAIGN
st.markdown("## By campaign")

by_campaign = query(
    """
    select
        campaign_name,
        sum(spend)                                                       as spend,
        sum(impressions)                                                 as impressions,
        sum(clicks)                                                      as clicks,
        sum(spend) / nullif(sum(clicks), 0)                              as cpc,
        sum(platform_reported_revenue)                                   as platform_revenue,
        sum(last_touch_revenue)                                          as last_touch_revenue,
        sum(platform_reported_revenue) / nullif(sum(spend), 0)           as platform_roas,
        sum(last_touch_revenue) / nullif(sum(spend), 0)                  as last_touch_roas
    from marts_marketing.fct_marketing_performance
    group by campaign_name
    order by spend desc
    """
)

st.dataframe(
    by_campaign,
    width="stretch",
    hide_index=True,
    column_config={
        "campaign_name": st.column_config.TextColumn("Campaign"),
        "spend": st.column_config.NumberColumn("Spend", format="$%.0f"),
        "impressions": st.column_config.NumberColumn("Impressions", format="%d"),
        "clicks": st.column_config.NumberColumn("Clicks", format="%d"),
        "cpc": st.column_config.NumberColumn("CPC", format="$%.2f"),
        "platform_revenue": st.column_config.NumberColumn("Platform rev", format="$%.0f"),
        "last_touch_revenue": st.column_config.NumberColumn("UTM rev", format="$%.0f"),
        "platform_roas": st.column_config.NumberColumn("Platform ROAS", format="%.2fx"),
        "last_touch_roas": st.column_config.NumberColumn("UTM ROAS", format="%.2fx"),
    },
)

# ───────────────────────────────────────────────────────── MONTHLY SPEND
st.markdown("## Monthly spend ramp")

monthly = query(
    """
    select
        date_trunc('month', date_day)::date as month,
        campaign_name,
        sum(spend)                           as spend
    from marts_marketing.fct_marketing_performance
    group by 1, 2
    order by month, spend desc
    """
)

monthly_chart = (
    alt.Chart(monthly)
    .mark_bar(cornerRadius=2)
    .encode(
        x=alt.X("month:T", axis=alt.Axis(title=None, format="%b %Y")),
        y=alt.Y("spend:Q", axis=alt.Axis(title="Spend (USD)", format="$,.0f"), stack="zero"),
        color=alt.Color(
            "campaign_name:N",
            scale=alt.Scale(range=EXEC_PALETTE),
            legend=alt.Legend(title="Campaign", orient="right", labelLimit=200),
        ),
        tooltip=[
            alt.Tooltip("month:T", title="Month", format="%B %Y"),
            alt.Tooltip("campaign_name:N", title="Campaign"),
            alt.Tooltip("spend:Q", title="Spend", format="$,.0f"),
        ],
    )
    .properties(height=320)
)
st.altair_chart(monthly_chart, width="stretch")

# ───────────────────────────────────────────────────────── FOOTER
st.markdown("---")
st.caption(
    "Models behind this page: `fct_marketing_performance`, `fct_blended_roas`, "
    "`fct_attribution_last_touch` — see "
    "[github.com/amanimulira/D2C-Data-Stack](https://github.com/amanimulira/D2C-Data-Stack)."
)
