# Raw data populate scripts

Run these once against each trainee's own Postgres 14 instance
(`localhost:5432`) before the training starts. Each trainee has their own
Postgres, so no namespacing is needed — everyone gets the same `raw` schema
described in the slide deck.

## Usage

```bash
psql -h localhost -U <your_user> -d <your_db> -f 01_create_schema_and_tables.sql
psql -h localhost -U <your_user> -d <your_db> -f 02_populate_raw_data.sql
```

Re-running the two scripts **in order** always produces identical data —
`01_create_schema_and_tables.sql` drops and recreates the `raw` schema, so
`02_populate_raw_data.sql` always starts from empty. Don't run
`02_populate_raw_data.sql` on its own a second time; it will fail on
duplicate primary keys. If you need to reset your environment mid-training,
run both scripts again, in order.

## What gets created

- `raw.customers` (~120 rows) and `raw.orders` (~500 rows) — the two tables
  used throughout the core Day 1 exercises, with deliberately inconsistent
  casing/spacing (e.g. order `status` values like `Shipped`/`OPEN`/`shipped`)
  that you'll clean up in the staging layer.
- `raw.products` (~40 rows) and `raw.order_items` (~1500 rows) — a bonus
  "verdieping" domain for exploring beyond the core exercise, once you've
  finished the guided exercises. Not required for the core hands-on tasks.
