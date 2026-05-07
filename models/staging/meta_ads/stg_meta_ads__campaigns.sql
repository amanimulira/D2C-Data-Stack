with source as (

    select * from {{ source('meta_ads', 'meta_ads_campaigns') }}

),

renamed as (

    select
        campaign_id,
        name             as campaign_name,
        objective        as campaign_objective,
        status           as campaign_status,
        daily_budget,
        utm_campaign,
        created_at       as campaign_created_at,
        'meta_ads'       as platform

    from source

)

select * from renamed
