# Reference solution — Day 1 answer key

This is the instructor's completed dbt project for Day 1 of "dbt voor het
BI Competence Center". It is **not** the starting point for the hands-on
exercises — during the training you build your own project from scratch
with `dbt init`. Use this afterwards to check your work, or if you get
stuck.

## Structure

- `models/staging/` — `stg_orders` / `stg_customers`: the core exercise,
  cleaning `raw.orders` / `raw.customers` (see slides 39-40).
- `models/curated/curated_customer_orders.sql` — the core exercise's final
  aggregation (see slide 42).
- `models/staging/stg_products.sql`, `stg_order_items.sql` and
  `models/curated/curated_product_sales.sql` — **bonus / "verdieping"**
  material, not covered in the slide deck. Explore these once you've
  finished the core exercises, if you want to see a second worked example
  (including a second `relationships` test pattern).

## Running it

1. Populate your `raw` schema first — see `../sql/README.md`.
2. Copy `profiles.yml.example` to `~/.dbt/profiles.yml` (or point
   `DBT_PROFILES_DIR` at a folder containing your own copy) and fill in
   your Postgres credentials.
3. From this folder: `dbt debug`, then `dbt build`, then `dbt docs generate`
   and `dbt docs serve` to browse the lineage graph.
