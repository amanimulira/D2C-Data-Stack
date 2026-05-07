{#
    Returns a SQL fragment that unions per-platform spend models into a single
    long-form spend table at (date, platform, campaign_id, campaign_name) grain.

    Currently sources Meta Ads only. To add Google Ads, TikTok, etc., extend the
    `platforms` list with `(model_name, platform_label)` tuples; the inner select
    must project the same columns in the same order.

    Usage in a model:
        {{ unioned_marketing_spend() }}
#}

{% macro unioned_marketing_spend() %}

    {% set platforms = [
        ('stg_meta_ads__ad_insights', 'meta_ads'),
    ] %}

    {% for model_name, platform_label in platforms %}
        select
            date_day,
            '{{ platform_label }}'                              as platform,
            campaign_id,
            sum(impressions)                                    as impressions,
            sum(clicks)                                         as clicks,
            sum(spend)                                          as spend,
            sum(reported_conversions)                           as reported_conversions,
            sum(reported_conversion_value)                      as reported_conversion_value
        from {{ ref(model_name) }}
        group by 1, 2, 3
        {% if not loop.last %}union all{% endif %}
    {% endfor %}

{% endmacro %}
