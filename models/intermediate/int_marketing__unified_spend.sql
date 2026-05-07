{#
    Long-form daily spend at (date, platform, campaign) grain. Today this is just
    Meta Ads — extend `unioned_marketing_spend` macro with Google Ads / TikTok
    when those connectors come online.
#}

with platform_spend as (

    {{ unioned_marketing_spend() }}

),

with_campaign_names as (

    select
        s.date_day,
        s.platform,
        s.campaign_id,
        coalesce(c.campaign_name, s.campaign_id)        as campaign_name,
        s.impressions,
        s.clicks,
        s.spend,
        s.reported_conversions,
        s.reported_conversion_value
    from platform_spend s
    left join {{ ref('stg_meta_ads__campaigns') }} c
           on s.campaign_id = c.campaign_id
          and s.platform    = 'meta_ads'

)

select * from with_campaign_names
