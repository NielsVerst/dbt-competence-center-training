-- Verdieping / bonus: not part of the core Day 1 exercise.
with items as (
    select * from {{ ref('stg_order_items') }}
),

products as (
    select * from {{ ref('stg_products') }}
)

select
    p.product_id,
    p.product_name,
    p.category,
    sum(i.quantity) as units_sold,
    sum(i.quantity * i.unit_price) as totale_omzet
from items i
join products p using (product_id)
group by 1, 2, 3
