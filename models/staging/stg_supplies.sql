with source as (
    select * from {{ source('ecom', 'raw_supplies') }}
),

renamed as (
    select
        {{ dbt_utils.generate_surrogate_key(['id', 'sku']) }} as supply_uuid,
        id as supply_id,
        name as supply_name,
        {{ cents_to_dollars('cost') }} as supply_cost,
        perishable as is_perishable_supply,
        sku as product_id
    from source
)

select * from renamed
