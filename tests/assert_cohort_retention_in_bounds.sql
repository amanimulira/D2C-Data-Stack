{#
    Singular test. The retention rate at month 0 (acquisition month) must always
    be 1.0 — every cohort customer is, by definition, active in their cohort
    month. Anything else means the join in customer_cohort_retention has drifted.
#}

select cohort_month, months_since_acquisition, retention_rate
from {{ ref('customer_cohort_retention') }}
where months_since_acquisition = 0
  and retention_rate <> 1.0
