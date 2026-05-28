with src as (
    select * from {{ source('ecom', 'raw_stores') }}
),

renamed as (
    select
        id as location_id,
        name as location_name,
        tax_rate,
        {{ dbt.date_trunc('day', 'opened_at') }} as opened_at
    from src
)

select * from renamed
