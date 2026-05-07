with source as (

    select * from {{ source('meta_ads', 'meta_ads_ad_insights') }}

),

renamed as (

    select
        date_day,
        campaign_id,
        ad_set_id,
        ad_id,

        impressions,
        clicks,
        spend,
        reported_conversions,
        reported_conversion_value,

        -- Derived rates so downstream marts can avoid divide-by-zero boilerplate.
        case when impressions > 0 then cast(clicks as numeric)      / impressions      else 0 end                                            as ctr,
        case when impressions > 0 then spend * 1000.0 / impressions else 0 end                                                              as cpm,
        case when clicks > 0      then spend / clicks               else null end                                                            as cpc,
        case when spend > 0       then reported_conversion_value / spend else 0 end                                                          as platform_reported_roas,

        'meta_ads'                                                                                                                            as platform

    from source

)

select * from renamed
