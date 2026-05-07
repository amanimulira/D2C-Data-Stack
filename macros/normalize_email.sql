{#
    Normalize an email column for use as a deterministic identity key.
    - lowercased
    - leading / trailing whitespace stripped
    - empty string -> null

    Usage:
        select {{ normalize_email('email') }} as email from ...
#}

{% macro normalize_email(column_name) %}
    nullif(trim(lower({{ column_name }})), '')
{% endmacro %}
