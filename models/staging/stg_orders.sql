with source as (
    select * from {{ source('ecom', 'raw_orders') }}
),

renamed as (
    select
        id as order_id,
        customer as customer_id,
        {{ dbt.date_trunc('day', 'ordered_at') }} as ordered_at,
        store_id,
        {{ cents_to_dollars('subtotal') }} as subtotal,
        {{ cents_to_dollars('tax_paid') }} as tax_paid,
        {{ cents_to_dollars('order_total') }} as order_total
    from source
)

select * from renamed
