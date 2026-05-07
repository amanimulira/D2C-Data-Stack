with source as (

    select * from {{ source('ga4', 'ga4_events') }}

),

renamed as (

    select
        event_id,
        event_name,
        event_timestamp,
        cast(event_timestamp as date)        as event_date,
        user_pseudo_id,
        session_id,
        page_location,
        page_title,

        -- GA4 source/medium/campaign — already pivoted out of event_params upstream.
        -- Normalize empty strings to GA4's documented placeholder vocabulary.
        coalesce(nullif(source,   ''), '(direct)')        as source,
        coalesce(nullif(medium,   ''), '(none)')          as medium,
        coalesce(nullif(campaign, ''), '(not set)')       as campaign,

        ga_session_number,
        coalesce(event_value, 0)             as event_value,
        coalesce(items_count, 0)             as items_count

    from source

)

select * from renamed
