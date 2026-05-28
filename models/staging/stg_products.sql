with src as (
    select * from {{ source('ecom', 'raw_products') }}
),

renamed as (
    select
        sku as product_id,
        name as product_name,
        type as product_type,
        {{ cents_to_dollars('price') }} as product_price,
        case
            when type = 'jaffle' then true
            else false
        end as is_food_item,
        case
            when type = 'beverage' then true
            else false
        end as is_drink_item
    from src
)

select * from renamed
