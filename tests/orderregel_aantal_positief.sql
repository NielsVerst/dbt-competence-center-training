-- Verdieping / bonus: een orderregel moet minstens 1 stuk bevatten
-- en een prijs hebben die niet negatief is.
SELECT
    order_item_id,
    quantity,
    unit_price
FROM {{ ref('stg_order_items') }}
WHERE quantity < 1 OR unit_price < 0
