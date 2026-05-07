{#
    Per-customer order rollup. One row per customer with lifetime metrics: order
    count, gross/net revenue, AOV, first/last order timestamps, days_since_last,
    and the source of the first order (used as the acquisition channel).
#}

with orders as (

    select * from {{ ref('int_orders__joined') }}

),

ordered as (

    select
        *,
        row_number() over (partition by customer_id order by ordered_at asc)  as order_seq,
        row_number() over (partition by customer_id order by ordered_at desc) as order_seq_desc
    from orders
    where customer_id is not null

),

first_order as (

    select
        customer_id,
        ordered_at         as first_ordered_at,
        order_date         as first_order_date,
        utm_source         as first_order_utm_source,
        utm_medium         as first_order_utm_medium,
        utm_campaign       as first_order_utm_campaign
    from ordered
    where order_seq = 1

),

last_order as (

    select
        customer_id,
        ordered_at         as last_ordered_at,
        order_date         as last_order_date
    from ordered
    where order_seq_desc = 1

),

aggregated as (

    select
        customer_id,
        count(*)                                                          as lifetime_order_count,
        sum(order_subtotal)                                               as lifetime_gross_subtotal,
        sum(net_subtotal_after_refunds)                                   as lifetime_net_subtotal,
        sum(order_total)                                                  as lifetime_order_total,
        sum(refund_amount)                                                as lifetime_refund_amount,
        avg(order_subtotal)                                               as average_order_value,
        sum(case when order_seq = 1 then 0 else 1 end)                    as repeat_order_count
    from ordered
    group by 1

)

select
    a.customer_id,
    a.lifetime_order_count,
    a.lifetime_gross_subtotal,
    a.lifetime_net_subtotal,
    a.lifetime_order_total,
    a.lifetime_refund_amount,
    a.average_order_value,
    a.repeat_order_count,
    case when a.lifetime_order_count > 1 then true else false end       as is_repeat_customer,

    f.first_ordered_at,
    f.first_order_date,
    f.first_order_utm_source                                              as acquisition_source,
    f.first_order_utm_medium                                              as acquisition_medium,
    f.first_order_utm_campaign                                            as acquisition_campaign,

    l.last_ordered_at,
    l.last_order_date

from aggregated a
left join first_order f on a.customer_id = f.customer_id
left join last_order  l on a.customer_id = l.customer_id
