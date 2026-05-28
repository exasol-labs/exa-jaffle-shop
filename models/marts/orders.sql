with base_orders as (
    select * from {{ ref('stg_orders') }}
),

base_order_items as (
    select * from {{ ref('stg_order_items') }}
),

base_products as (
    select * from {{ ref('stg_products') }}
),

order_items_summary as (
    select
        base_order_items.order_id,
        sum(case when base_products.is_food_item then 1 else 0 end) as count_food_items,
        sum(case when base_products.is_drink_item then 1 else 0 end) as count_drink_items,
        sum(1) as count_items
    from base_order_items
    left join base_products on base_order_items.product_id = base_products.product_id
    group by base_order_items.order_id
),

mart as (
    select
        base_orders.order_id,
        base_orders.customer_id,
        base_orders.ordered_at,
        base_orders.store_id,
        base_orders.subtotal,
        base_orders.tax_paid,
        base_orders.order_total,
        order_items_summary.count_food_items,
        order_items_summary.count_drink_items,
        order_items_summary.count_items
    from base_orders
    left join order_items_summary on base_orders.order_id = order_items_summary.order_id
)

select * from mart
