with source as (

    select * from {{ source('klaviyo', 'klaviyo_profiles') }}

),

renamed as (

    select
        profile_id,
        {{ normalize_email('email') }}    as email,
        created_at                         as profile_created_at,
        accepts_marketing,
        country_code

    from source

)

select * from renamed
