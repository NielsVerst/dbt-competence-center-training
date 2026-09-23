with orders as (
    select * from {{ ref('stg_orders') }}
),

customers as (
    select * from {{ ref('stg_customers') }}
)

select
    c.customer_id,
    c.customer_name,
    count(o.order_id) as aantal_orders,
    sum(o.order_amount) as totale_omzet
from orders o
join customers c using (customer_id)
group by 1, 2
