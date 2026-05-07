with source as (

    select * from {{ source('shopify', 'shopify_order_lines') }}

),

renamed as (

    select
        order_line_id,
        order_id,
        product_id,
        sku,
        title             as product_title,
        quantity,
        price             as unit_price,
        total_discount    as line_discount,

        -- Pre-computed line economics so downstream marts don't repeat the math
        cast(quantity as numeric) * price                       as gross_line_revenue,
        cast(quantity as numeric) * price - total_discount      as net_line_revenue

    from source

)

select * from renamed
