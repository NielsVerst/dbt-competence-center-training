with source as (
    select * from {{ source('raw', 'orders') }}
)

select
    order_id,
    customer_id,
    cast(order_date as date) as order_date,
    lower(status) as order_status,
    amount::numeric(10,2) as order_amount
from source
