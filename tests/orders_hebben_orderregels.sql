-- Singular test: elke order die niet geannuleerd is, moet minstens één
-- orderregel hebben. Een order zonder regels is een lege order en wijst op
-- ontbrekende data in order_items.
-- De left join houdt alle orders over; orders zonder match krijgen NULL
-- in de kolommen van stg_order_items. Die rijen zijn de fouten.
SELECT
    o.order_id,
    o.order_status
FROM {{ ref('stg_orders') }} o
LEFT JOIN {{ ref('stg_order_items') }} i
    ON o.order_id = i.order_id
WHERE o.order_status <> 'cancelled'
