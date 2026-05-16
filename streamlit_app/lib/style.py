"""Executive-report visual layer: CSS injection + Altair theme.

The aesthetic target is a one-pager you'd put in front of a CFO at a
board meeting — serif headings, restrained palette (slate + a single
deep-blue accent), generous whitespace, no chartjunk. Every Streamlit
page calls `apply_theme()` once at the top.
"""
from __future__ import annotations

import altair as alt
import streamlit as st

# Slate-900 → Slate-300, then a single accent. Used in the Altair theme
# as the categorical palette so multi-series charts default to readable
# monochrome ramps before reaching for color.
EXEC_PALETTE = [
    "#0F172A",  # slate-900 — primary
    "#475569",  # slate-600
    "#94A3B8",  # slate-400
    "#1E3A8A",  # blue-900 — accent for highlight series
    "#7C3AED",  # violet-600 — secondary accent
    "#0E7490",  # cyan-700
]

_CSS = """
<style>
  /* Tighter layout — boardpacks don't sprawl */
  .block-container {
    padding-top: 2.5rem;
    padding-bottom: 4rem;
    max-width: 1200px;
  }

  /* Serif headings, sans body — the FT/Economist split */
  h1, h2, h3, h4 {
    font-family: 'Charter', 'Georgia', 'Times New Roman', serif !important;
    color: #0F172A !important;
    letter-spacing: -0.01em;
  }
  h1 { font-weight: 600; font-size: 2.1rem; margin-bottom: 0.5rem; }
  h2 { font-weight: 500; font-size: 1.5rem; margin-top: 2.5rem; }
  h3 { font-weight: 500; font-size: 1.15rem; color: #334155 !important; }

  /* KPI cards — flat, no shadow, just a hairline border */
  [data-testid="stMetric"] {
    background: #F8FAFC;
    border: 1px solid #E2E8F0;
    border-radius: 4px;
    padding: 16px 20px;
  }
  [data-testid="stMetricLabel"] {
    color: #64748B !important;
    font-size: 0.75rem !important;
    text-transform: uppercase;
    letter-spacing: 0.06em;
    font-weight: 500;
  }
  [data-testid="stMetricValue"] {
    font-family: 'Charter', 'Georgia', serif !important;
    font-size: 1.85rem !important;
    font-weight: 600;
    color: #0F172A !important;
  }
  [data-testid="stMetricDelta"] {
    font-size: 0.8rem !important;
  }

  /* Hide Streamlit's chrome to feel more like a published report */
  header[data-testid="stHeader"] { background: transparent; }
  #MainMenu, footer { visibility: hidden; }

  /* Sidebar: cleaner, more report-like */
  [data-testid="stSidebar"] {
    background: #F8FAFC;
    border-right: 1px solid #E2E8F0;
  }
  [data-testid="stSidebar"] h1 {
    font-size: 1.1rem;
    padding-top: 0.5rem;
  }

  /* Subtle horizontal rules between sections */
  hr {
    border: 0;
    border-top: 1px solid #E2E8F0;
    margin: 2.5rem 0 1.5rem 0;
  }

  /* Caption text for footnotes */
  .stCaption, [data-testid="stCaptionContainer"] {
    color: #64748B;
    font-size: 0.85rem;
    font-style: italic;
  }

  /* Tables: zebra-stripe and tighten */
  [data-testid="stDataFrame"] {
    border: 1px solid #E2E8F0;
    border-radius: 4px;
  }
</style>
"""


def _exec_theme() -> dict:
    """Altair theme — quiet axes, monochrome categorical default, serif titles."""
    return {
        "config": {
            "view": {"stroke": "transparent", "continuousHeight": 320, "continuousWidth": 600},
            "background": "#FFFFFF",
            "font": "system-ui, -apple-system, 'Helvetica Neue', sans-serif",
            "title": {
                "fontSize": 13,
                "fontWeight": 500,
                "color": "#0F172A",
                "anchor": "start",
                "offset": 12,
                "font": "Charter, Georgia, serif",
            },
            "axis": {
                "labelColor": "#64748B",
                "titleColor": "#475569",
                "labelFontSize": 11,
                "titleFontSize": 11,
                "titleFontWeight": 400,
                "titlePadding": 10,
                "gridColor": "#F1F5F9",
                "gridWidth": 1,
                "domainColor": "#CBD5E1",
                "tickColor": "#CBD5E1",
                "labelPadding": 6,
            },
            "axisY": {"grid": True, "domain": False, "ticks": False},
            "axisX": {"grid": False},
            "legend": {
                "labelColor": "#475569",
                "titleColor": "#0F172A",
                "labelFontSize": 11,
                "titleFontSize": 11,
                "titleFontWeight": 500,
                "padding": 4,
                "symbolType": "square",
            },
            "range": {"category": EXEC_PALETTE, "ramp": ["#F1F5F9", "#0F172A"]},
            "bar": {"color": EXEC_PALETTE[0]},
            "line": {"color": EXEC_PALETTE[0], "strokeWidth": 2},
            "point": {"color": EXEC_PALETTE[0]},
            "area": {"color": EXEC_PALETTE[0], "opacity": 0.15},
        }
    }


_THEME_REGISTERED = False


def apply_theme() -> None:
    """Inject CSS and register the Altair theme. Idempotent — call at the top
    of every page."""
    global _THEME_REGISTERED
    st.markdown(_CSS, unsafe_allow_html=True)
    if not _THEME_REGISTERED:
        alt.themes.register("exec", _exec_theme)
        alt.themes.enable("exec")
        _THEME_REGISTERED = True


def section_caption(text: str) -> None:
    """One-line italic footnote-style commentary below a chart."""
    st.markdown(
        f"<div style='color:#64748B; font-size:0.88rem; font-style:italic; "
        f"margin-top:-0.5rem; margin-bottom:1.5rem;'>{text}</div>",
        unsafe_allow_html=True,
    )
