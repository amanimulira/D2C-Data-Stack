with source as (

    select * from {{ source('klaviyo', 'klaviyo_flows') }}

),

renamed as (

    select
        flow_id,
        name             as flow_name,
        trigger_type,
        status

    from source

)

select * from renamed
