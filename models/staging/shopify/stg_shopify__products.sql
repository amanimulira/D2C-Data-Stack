with source as (

    select * from {{ source('shopify', 'shopify_products') }}

),

renamed as (

    select
        product_id,
        title              as product_title,
        product_type,
        vendor,
        sku,
        currency,
        price              as product_price,
        cost               as product_cost,
        price - cost       as product_unit_margin,
        case when price > 0 then (price - cost) / price else null end as product_margin_pct,
        status             as product_status,
        created_at         as product_created_at

    from source

)

select * from renamed
