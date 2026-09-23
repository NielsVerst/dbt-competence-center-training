-- sql/01_create_schema_and_tables.sql
-- Idempotent: safe to re-run. Drops and recreates the `raw` schema used as
-- the training's dbt source() layer.

DROP SCHEMA IF EXISTS raw CASCADE;
CREATE SCHEMA raw;

-- Core domain (matches the slide deck exactly)

CREATE TABLE raw.customers (
    customer_id integer PRIMARY KEY,
    name         text,
    country      text
);

CREATE TABLE raw.orders (
    order_id     integer PRIMARY KEY,
    customer_id  integer,
    order_date   date,
    status       text,
    amount       numeric(10,2)
);

-- Bonus / "verdieping" domain (not shown in the slide deck)

CREATE TABLE raw.products (
    product_id    integer PRIMARY KEY,
    product_name  text,
    category      text,
    unit_price    numeric(10,2)
);

CREATE TABLE raw.order_items (
    order_item_id integer PRIMARY KEY,
    order_id      integer,
    product_id    integer,
    quantity      integer,
    unit_price    numeric(10,2)
);
