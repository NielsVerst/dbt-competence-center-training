-- sql/02_populate_raw_data.sql
-- Deterministic (no random()) — re-running always yields identical data.
-- Must be run after 01_create_schema_and_tables.sql.

-- raw.customers (~120 rows). Deliberately inconsistent name/country casing
-- and spacing, cycling deterministically by customer_id.
INSERT INTO raw.customers (customer_id, name, country)
SELECT
    100 + gs AS customer_id,
    CASE gs % 4
        WHEN 0 THEN '  Jansen ' || gs
        WHEN 1 THEN 'de Vries' || gs
        WHEN 2 THEN 'BAKKER ' || gs || ' '
        ELSE 'Visser' || gs
    END AS name,
    CASE gs % 3
        WHEN 0 THEN 'nl'
        WHEN 1 THEN 'NL'
        ELSE ' Nl'
    END AS country
FROM generate_series(1, 120) AS gs;

-- raw.products (~40 rows). Deliberately inconsistent product_name/category
-- casing and spacing.
INSERT INTO raw.products (product_id, product_name, category, unit_price)
SELECT
    gs AS product_id,
    CASE gs % 5
        WHEN 0 THEN 'Widget ' || gs
        WHEN 1 THEN '  Gadget' || gs
        WHEN 2 THEN 'GIZMO ' || gs
        WHEN 3 THEN 'Doohickey' || gs || ' '
        ELSE 'Thingamajig ' || gs
    END AS product_name,
    CASE gs % 4
        WHEN 0 THEN 'electronics'
        WHEN 1 THEN 'Electronics'
        WHEN 2 THEN 'home'
        ELSE 'HOME'
    END AS category,
    (5 + (gs % 20) * 3.50)::numeric(10,2) AS unit_price
FROM generate_series(1, 40) AS gs;

-- raw.orders (~500 rows). status cycles through mixed-case variants of the
-- same 4 logical statuses, matching the slide deck's dirty-data example.
INSERT INTO raw.orders (order_id, customer_id, order_date, status, amount)
SELECT
    gs AS order_id,
    100 + (gs % 120) + 1 AS customer_id,
    (DATE '2026-01-01' + ((gs * 37) % 240) * INTERVAL '1 day')::date AS order_date,
    CASE gs % 5
        WHEN 0 THEN 'Shipped'
        WHEN 1 THEN 'OPEN'
        WHEN 2 THEN 'shipped'
        WHEN 3 THEN 'cancelled'
        ELSE 'Cancelled'
    END AS status,
    (10 + (gs % 50) * 4.25)::numeric(10,2) AS amount
FROM generate_series(1, 500) AS gs;

-- raw.order_items (~1500 rows, roughly 3 line items per order).
INSERT INTO raw.order_items (order_item_id, order_id, product_id, quantity, unit_price)
SELECT
    gs AS order_item_id,
    ((gs - 1) % 500) + 1 AS order_id,
    ((gs * 7) % 40) + 1 AS product_id,
    1 + (gs % 4) AS quantity,
    (5 + ((gs * 3) % 20) * 3.50)::numeric(10,2) AS unit_price
FROM generate_series(1, 1500) AS gs;
