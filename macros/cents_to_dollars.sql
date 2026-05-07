{#
    Many e-commerce APIs (Stripe, Shopify cart APIs) return monetary amounts in
    minor units (cents). Use this to convert to major units (dollars) at the
    staging layer so all downstream models work in dollars.

    Usage:
        select {{ cents_to_dollars('amount_cents') }} as amount, ...
#}

{% macro cents_to_dollars(column_name, decimals=2) %}
    cast({{ column_name }} as numeric) / 100.0
{% endmacro %}
