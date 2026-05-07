with source as (

    select * from {{ source('klaviyo', 'klaviyo_campaigns') }}

),

renamed as (

    select
        campaign_id,
        name             as campaign_name,
        subject_line,
        channel,
        sent_at,
        cast(sent_at as date) as sent_date,
        recipient_count

    from source

)

select * from renamed
