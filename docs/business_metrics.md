# Business Metrics

The metrics this stack is designed to compute, with formulas, the model that
produces them, and notes on where the standard definition trips operators up.

---

## Revenue

### Gross merchandise value (GMV)
Sum of `order_subtotal` across all orders in the period, before discount, tax,
shipping, and refunds. Almost never the right number to report — but it's the
one Shopify reports by default in its admin dashboard.

**Model:** `fct_orders.order_subtotal`

### Net revenue
`order_subtotal - refund_amount`. Excludes tax, shipping. This is the
revenue line you pay COGS against. The **canonical revenue metric** in this
stack.

**Model:** `fct_orders.net_subtotal_after_refunds`

### Contribution margin
`net_revenue - COGS`. Excludes shipping cost, payment-processing fees, and
fixed overhead — those vary by carrier / processor and are usually pulled in
from a separate finance model. In production add `- fulfillment_cost - payment_fees`.

**Model:** `fct_orders.contribution_margin`

---

## Marketing efficiency

### Platform-reported ROAS
What Meta / Google / TikTok report in their own dashboards. Includes
view-through and 7-day click attribution and tends to **overstate** by 1.5–3x.

**Model:** `fct_marketing_performance.platform_reported_roas`

### Last-touch ROAS (UTM-based)
Revenue from orders whose UTM matches the campaign, divided by spend. Strict,
deterministic, **understates** upper-funnel channels (they get no credit).

**Model:** `fct_marketing_performance.last_touch_roas`

### Blended ROAS / MER
Total revenue (across all channels — paid, organic, email, direct) divided
by total paid spend. Insulated from attribution wars between platforms.
The headline marketing health metric a CFO can trust.

**Formula:** `total_revenue / total_paid_spend`

**Model:** `fct_blended_roas.blended_roas`

### Contribution-margin MER
Same denominator (paid spend), but numerator is `total_contribution_margin`
instead of revenue. The version of MER that survives a P&L review — a 3.0
revenue MER on 25% margin is the same business as a 1.0 revenue MER on
75% margin.

**Model:** `fct_blended_roas.contribution_margin_mer`

---

## Customer economics

### Customer Acquisition Cost (CAC)
`total_paid_spend / new_customers_acquired`. Usually quoted blended (across all
paid channels). Channel-level CAC is `channel_spend / channel-attributed new
customers` — useful but attribution-fragile.

**Model:** `fct_marketing_performance.cac_last_touch`,
`analyses/cohort_payback_curve.sql` for cohort blended CAC.

### Lifetime Value (LTV)
Cumulative net revenue per customer at a chosen window. Quote at 30/60/90/180/365
days. The 90-day mark is the working operator's go-to (long enough to capture
the second purchase pattern, short enough to be timely).

For unit-economics decisions, use **contribution-margin LTV**, not revenue LTV.

**Model:** `customer_ltv` — provides both revenue and margin variants at
multiple windows.

### Payback period
Months until cumulative contribution margin per customer >= CAC. The
working-capital question: how long until the cash from a customer covers
the cash spent acquiring them?

**Analysis:** `analyses/cohort_payback_curve.sql` — `payback_ratio` >= 1.0
means the cohort has paid back.

### Repeat purchase rate
Fraction of customers with `lifetime_order_count > 1`. The single best
product-market-fit signal in D2C. Below 20% is a customer-acquisition treadmill;
above 40% is a brand.

**Model:** `dim_customers.is_repeat_customer`

### RFM segments
Recency / Frequency / Monetary scoring on a 1-5 scale, plus named lifecycle
buckets (Champions, Loyal, At Risk, Hibernating, …). Drives Klaviyo segmentation.

**Model:** `customer_rfm`

---

## Cohort retention

Monthly grid of `cohort_month × months_since_acquisition`. Each cell shows the
percentage of the cohort that placed at least one order in that month.

A healthy D2C cohort retention curve plateaus rather than zeroing out — month-12
retention of 8–15% is normal for a $40 AOV consumable; under 5% indicates a
trial-only product that won't compound.

**Model:** `customer_cohort_retention.retention_rate`
