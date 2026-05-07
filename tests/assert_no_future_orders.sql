{#
    Singular test. Fails if any order has been timestamped in the future —
    a common symptom of a clock-skew or timezone bug in checkout instrumentation.
#}

select order_id, ordered_at
from {{ ref('fct_orders') }}
where ordered_at > current_date + interval '1 day'
