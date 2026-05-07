{#
    Date dimension. Built once and reused across every fct_* model that needs
    a contiguous calendar (cohort retention, blended ROAS, payback curves).
#}

with date_spine as (

    {{
        dbt_utils.date_spine(
            datepart="day",
            start_date="cast('" ~ var('start_date') ~ "' as date)",
            end_date="cast('" ~ var('end_date') ~ "' as date)"
        )
    }}

)

select
    cast(date_day as date)                                      as date_day,
    extract(year  from date_day)                                as year,
    extract(month from date_day)                                as month,
    extract(day   from date_day)                                as day_of_month,
    extract(dow   from date_day)                                as day_of_week,
    cast(date_trunc('week',    date_day) as date)               as week_start_date,
    cast(date_trunc('month',   date_day) as date)               as month_start_date,
    cast(date_trunc('quarter', date_day) as date)               as quarter_start_date,
    cast(date_trunc('year',    date_day) as date)               as year_start_date

from date_spine
