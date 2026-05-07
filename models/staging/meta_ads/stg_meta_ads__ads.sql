with source as (

    select * from {{ source('meta_ads', 'meta_ads_ads') }}

),

renamed as (

    select
        ad_id,
        ad_set_id,
        name             as ad_name,
        creative_type,
        status           as ad_status,
        created_at       as ad_created_at

    from source

)

select * from renamed
