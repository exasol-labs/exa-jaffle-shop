with customers as (
    select * from {{ ref('stg_customers') }}
),

orders as (
    select * from {{ ref('stg_orders') }}
),

customer_orders as (
    select
        customer_id,
        min(ordered_at) as first_order_date,
        max(ordered_at) as most_recent_order_date,
        count(order_id) as number_of_orders,
        sum(order_total) as lifetime_value
    from orders
    group by customer_id
),

final as (
    select
        customers.customer_id,
        customers.customer_name,
        customer_orders.first_order_date,
        customer_orders.most_recent_order_date,
        coalesce(customer_orders.number_of_orders, 0) as number_of_orders,
        coalesce(customer_orders.lifetime_value, 0) as lifetime_value,
        case
            when customer_orders.customer_id is null then 'new'
            when customer_orders.number_of_orders = 1 then 'one-time'
            else 'returning'
        end as customer_type
    from customers
    left join customer_orders using (customer_id)
)

select * from final
