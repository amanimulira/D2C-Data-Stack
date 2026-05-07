with source as (

    select * from {{ source('shopify', 'shopify_refunds') }}

),

renamed as (

    select
        refund_id,
        order_id,
        created_at         as refunded_at,
        cast(created_at as date) as refund_date,
        refund_amount,
        reason             as refund_reason

    from source

)

select * from renamed
