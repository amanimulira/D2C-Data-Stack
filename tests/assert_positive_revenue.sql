{#
    Singular test. Fails if any order has a negative subtotal. Discounts can
    bring a Shopify order's net to zero or near-zero, but never below zero —
    a negative subtotal indicates a refund being double-applied or a bug.
#}

select order_id, order_subtotal
from {{ ref('fct_orders') }}
where order_subtotal < 0
