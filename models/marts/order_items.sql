with base_order_items as (
    select * from {{ ref('stg_order_items') }}
),

base_orders as (
    select * from {{ ref('stg_orders') }}
),

base_products as (
    select * from {{ ref('stg_products') }}
),

base_supplies as (
    select * from {{ ref('stg_supplies') }}
),

product_supplies_cost as (
    select
        product_id,
        sum(supply_cost) as supply_cost
    from base_supplies
    group by product_id
),

mart as (
    select
        base_order_items.order_item_id,
        base_order_items.order_id,
        base_order_items.product_id,
        base_orders.ordered_at,
        base_orders.customer_id,
        base_products.product_name,
        base_products.product_type,
        base_products.product_price,
        base_products.is_food_item,
        base_products.is_drink_item,
        coalesce(product_supplies_cost.supply_cost, 0) as supply_cost
    from base_order_items
    left join base_orders on base_order_items.order_id = base_orders.order_id
    left join base_products on base_order_items.product_id = base_products.product_id
    left join product_supplies_cost on base_order_items.product_id = product_supplies_cost.product_id
)

select * from mart
