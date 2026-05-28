with order_items as (
    select * from {{ ref('stg_order_items') }}
),

orders as (
    select * from {{ ref('stg_orders') }}
),

products as (
    select * from {{ ref('stg_products') }}
),

supplies as (
    select * from {{ ref('stg_supplies') }}
),

product_supplies_cost as (
    select
        product_id,
        sum(supply_cost) as supply_cost
    from supplies
    group by product_id
),

final as (
    select
        order_items.order_item_id,
        order_items.order_id,
        order_items.product_id,
        orders.ordered_at,
        orders.customer_id,
        products.product_name,
        products.product_type,
        products.product_price,
        products.is_food_item,
        products.is_drink_item,
        coalesce(product_supplies_cost.supply_cost, 0) as supply_cost
    from order_items
    left join orders using (order_id)
    left join products using (product_id)
    left join product_supplies_cost using (product_id)
)

select * from final
