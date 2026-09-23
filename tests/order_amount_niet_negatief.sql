-- Singular test: een order mag geen negatief bedrag hebben.
-- De test slaagt als deze query 0 rijen teruggeeft; elke rij is een fout.
SELECT
    order_id,
    order_amount
FROM {{ ref('stg_orders') }}
WHERE order_amount < 0
