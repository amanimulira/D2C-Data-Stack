{#
    RFM scoring for lifecycle-marketing segmentation. Quintile scores 1-5 on:
      • Recency  — days since last order (lower = better, scored 5 for newest)
      • Frequency — lifetime order count
      • Monetary  — lifetime revenue

    Concatenate the three scores to get an RFM cell (e.g. "555" = best, "111"
    = at risk). Klaviyo / Postscript / Attentive segments map cleanly to these.
#}

with base as (

    select
        ch.customer_id,
        ch.lifetime_order_count                                            as frequency,
        ch.lifetime_net_subtotal                                           as monetary,
        {{ dbt.datediff('ch.last_order_date', "current_date", 'day') }} as recency_days
    from {{ ref('int_customers__order_history') }} ch

),

scored as (

    select
        customer_id,
        recency_days,
        frequency,
        monetary,
        ntile(5) over (order by recency_days desc) as recency_score,
        ntile(5) over (order by frequency        ) as frequency_score,
        ntile(5) over (order by monetary         ) as monetary_score
    from base

)

select
    customer_id,
    recency_days,
    frequency,
    monetary,
    recency_score,
    frequency_score,
    monetary_score,
    cast(recency_score as varchar) || cast(frequency_score as varchar) || cast(monetary_score as varchar) as rfm_cell,

    case
        when recency_score >= 4 and frequency_score >= 4 and monetary_score >= 4 then 'Champions'
        when recency_score >= 3 and frequency_score >= 4                          then 'Loyal'
        when recency_score >= 4 and frequency_score <= 2                          then 'New'
        when recency_score <= 2 and frequency_score >= 4                          then 'At Risk'
        when recency_score <= 2 and frequency_score <= 2                          then 'Hibernating'
        else 'Active'
    end                                                                          as rfm_segment

from scored
