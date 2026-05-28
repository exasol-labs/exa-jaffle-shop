with orders as (
    select * from {{ ref('stg_orders') }}
),

order_items as (
    select * from {{ ref('stg_order_items') }}
),

products as (
    select * from {{ ref('stg_products') }}
),

order_items_summary as (
    select
        order_items.order_id,
        sum(case when products.is_food_item then 1 else 0 end) as count_food_items,
        sum(case when products.is_drink_item then 1 else 0 end) as count_drink_items,
        sum(1) as count_items
    from order_items
    left join products on order_items.product_id = products.product_id
    group by order_items.order_id
),

final as (
    select
        orders.order_id,
        orders.customer_id,
        orders.ordered_at,
        orders.store_id,
        orders.subtotal,
        orders.tax_paid,
        orders.order_total,
        order_items_summary.count_food_items,
        order_items_summary.count_drink_items,
        order_items_summary.count_items
    from orders
    left join order_items_summary using (order_id)
)

select * from final
