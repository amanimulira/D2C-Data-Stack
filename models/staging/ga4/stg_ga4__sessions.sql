{#
    Sessionizes the GA4 event stream into one row per session by aggregating
    over `(user_pseudo_id, session_id)`. We capture the first source/medium/
    campaign of the session (channel attribution) and a few funnel flags.
#}

with events as (

    select * from {{ ref('stg_ga4__events') }}

),

session_first_touch as (

    select
        user_pseudo_id,
        session_id,
        source,
        medium,
        campaign,
        event_timestamp                                              as session_first_event_at,
        row_number() over (
            partition by user_pseudo_id, session_id
            order by event_timestamp asc
        )                                                            as rn
    from events

),

aggregated as (

    select
        user_pseudo_id,
        session_id,
        min(event_timestamp)                                          as session_started_at,
        max(event_timestamp)                                          as session_ended_at,
        max(ga_session_number)                                        as session_number,

        max(case when event_name = 'page_view'      then 1 else 0 end) as had_page_view,
        max(case when event_name = 'view_item'      then 1 else 0 end) as had_view_item,
        max(case when event_name = 'add_to_cart'    then 1 else 0 end) as had_add_to_cart,
        max(case when event_name = 'begin_checkout' then 1 else 0 end) as had_begin_checkout,
        max(case when event_name = 'purchase'       then 1 else 0 end) as had_purchase,

        sum(case when event_name = 'page_view' then 1 else 0 end)      as page_view_count,
        sum(case when event_name = 'purchase'  then event_value else 0 end) as purchase_value
    from events
    group by 1, 2

)

select
    a.user_pseudo_id,
    a.session_id,
    a.session_started_at,
    cast(a.session_started_at as date)                                as session_date,
    a.session_ended_at,
    a.session_number,

    f.source                                                          as session_source,
    f.medium                                                          as session_medium,
    f.campaign                                                        as session_campaign,

    a.had_page_view,
    a.had_view_item,
    a.had_add_to_cart,
    a.had_begin_checkout,
    a.had_purchase,
    a.page_view_count,
    a.purchase_value

from aggregated a
left join session_first_touch f
       on a.user_pseudo_id = f.user_pseudo_id
      and a.session_id     = f.session_id
      and f.rn = 1
