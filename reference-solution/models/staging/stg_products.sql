-- Verdieping / bonus: not part of the core Day 1 exercise.
with source as (
    select * from {{ source('raw', 'products') }}
)

select
    product_id,
    trim(product_name) as product_name,
    lower(category) as category,
    unit_price::numeric(10,2) as unit_price
from source
