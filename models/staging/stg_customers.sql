{{ staging_config() }}

with source as (
    select * from {{ source('raw', 'customers') }}
)
select
    customer_id,
    trim(name) as customer_name,
    upper(country) as country_code
from source
