with source as (

    select * from {{ source('meta_ads', 'meta_ads_ad_sets') }}

),

renamed as (

    select
        ad_set_id,
        campaign_id,
        name             as ad_set_name,
        optimization_goal,
        status           as ad_set_status,
        created_at       as ad_set_created_at

    from source

)

select * from renamed
