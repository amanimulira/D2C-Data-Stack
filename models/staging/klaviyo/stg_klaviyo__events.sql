with source as (

    select * from {{ source('klaviyo', 'klaviyo_events') }}

),

renamed as (

    select
        event_id,
        profile_id,
        {{ normalize_email('email') }}                              as email,

        -- Normalize event names to a controlled vocabulary so downstream marts
        -- can rely on enum-like values rather than free-text Klaviyo strings.
        case
            when event_name = 'Placed Order'        then 'placed_order'
            when event_name = 'Started Checkout'    then 'started_checkout'
            when event_name = 'Received Email'      then 'received_email'
            when event_name = 'Opened Email'        then 'opened_email'
            when event_name = 'Clicked Email'       then 'clicked_email'
            when event_name = 'Received SMS'        then 'received_sms'
            when event_name = 'Subscribed to List'  then 'subscribed_to_list'
            else lower(replace(event_name, ' ', '_'))
        end                                                          as event_type,

        event_at,
        cast(event_at as date)                                       as event_date,
        coalesce(event_value, 0)                                     as event_value,

        nullif(campaign_id, '')          as campaign_id,
        nullif(flow_id, '')              as flow_id,
        nullif(message_id, '')           as message_id,
        nullif(attributed_order_id, '')  as attributed_order_id,

        case
            when nullif(campaign_id, '') is not null then 'campaign'
            when nullif(flow_id, '')     is not null then 'flow'
            else 'other'
        end                                                          as message_source

    from source

)

select * from renamed
