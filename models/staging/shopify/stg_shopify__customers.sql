with source as (

    select * from {{ source('shopify', 'shopify_customers') }}

),

renamed as (

    select
        customer_id,
        {{ normalize_email('email') }}                  as email,
        first_name,
        last_name,
        nullif(phone, '')                               as phone,
        country_code,
        accepts_marketing,
        created_at                                      as customer_created_at,
        updated_at                                      as customer_updated_at

    from source

)

select * from renamed
