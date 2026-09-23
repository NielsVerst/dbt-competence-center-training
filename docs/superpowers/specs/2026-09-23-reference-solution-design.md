# dbt Day-1 Reference Solution & Raw Data Populate Scripts — Design

## Purpose

Build an answer-key / reference dbt project for the "dbt voor het BI Competence
Center" Day 1 training (SSC-ICT, D-Data), plus standalone SQL scripts that
populate the Postgres `raw` schema the training's `source()` definitions point
at. Trainees build their own project from scratch during the hands-on
exercises (`dbt init`); this reference project is what they can diff their
own work against afterwards, and what the trainer uses to demo/verify.

## Context

- Source material: `dbt voor het BI Competence Center.pptx` (67 slides, Day 1
  only) and `Trainingsvoorstel_SSC-ICT_dbt.docx` (training proposal).
- Target audience: ~12 trainees, mixed experience, each working in their own
  VS Code Server with dbt-core + dbt-postgres preinstalled, against their own
  Postgres 14 instance on `localhost:5432`. No shared infrastructure — no
  namespacing/isolation concerns between trainees.
- Stack constraint: Postgres only, dbt-core only (no dbt Cloud, no extra
  Python packages beyond what's preinstalled) — the populate scripts must be
  plain SQL, runnable via `psql` or any Postgres client, no external tooling.
- Day 1 scope only. Day 2 (materializations beyond view/table, incremental
  models, Jinja/macros, snapshots, seeds, packages, CI/CD, deployment) is
  explicitly not covered by the current slide deck and is out of scope here.

## Repo Layout

Everything lives inside the existing `dbt-competence-center-training/` git
repo (already scaffolded with README + .gitignore covering `profiles.yml`,
`target/`, `dbt_packages/`, `logs/`).

```
dbt-competence-center-training/
├── README.md                          # updated: repo layout & workflow
├── sql/
│   ├── 01_create_schema_and_tables.sql   # raw schema + 4 tables, idempotent
│   ├── 02_populate_raw_data.sql          # generate_series-based dirty data
│   └── README.md                         # how/when to run against localhost:5432
└── reference-solution/
    ├── README.md                       # "instructor answer key, not the starting point"
    ├── dbt_project.yml                 # name/profile 'ssc_ict_bi' (matches slide 14)
    ├── profiles.yml.example            # documented; real profiles.yml gitignored
    └── models/
        ├── staging/
        │   ├── sources.yml             # raw.orders, raw.customers, raw.products, raw.order_items
        │   ├── schema.yml              # tests + descriptions on stg_ models
        │   ├── stg_orders.sql
        │   ├── stg_customers.sql
        │   ├── stg_products.sql        # bonus, clearly marked
        │   └── stg_order_items.sql     # bonus, clearly marked
        └── curated/
            ├── schema.yml
            ├── curated_customer_orders.sql   # matches slide 42 exactly
            └── curated_product_sales.sql     # bonus, clearly marked
```

## Data Model

### Core (must match the slide deck 1:1 — this is the literal answer key)

- `raw.orders(order_id, customer_id, order_date, status, amount)`
  — ~500 rows. `status` deliberately mixed-case/inconsistent
  (`Shipped`/`OPEN`/`shipped`/`cancelled`/`Cancelled`), mirroring slide 37.
- `raw.customers(customer_id, name, country)`
  — ~120 rows. `name`/`country` with inconsistent spacing/casing, mirroring
  slide 37.
- `stg_orders.sql` / `stg_customers.sql` — exact cleaning logic from slides
  39–40 (cast `order_date`, lowercase `status` → `order_status`, cast
  `amount` → `order_amount`; trim `name` → `customer_name`, uppercase
  `country` → `country_code`). Materialized as **view**.
- `curated_customer_orders.sql` — exact logic from slide 42: join staging
  models via `ref()`, aggregate `aantal_orders` (count) and `totale_omzet`
  (sum) per customer. Materialized as **table**.

### Bonus extras (clearly marked as "verdieping" — separate from the core exercise)

- `raw.products(product_id, product_name, category, unit_price)` — ~40 rows,
  same dirty-data style (inconsistent casing/spacing).
- `raw.order_items(order_item_id, order_id, product_id, quantity, unit_price)`
  — ~1500 rows, line items per order.
- `stg_products.sql` / `stg_order_items.sql` → `curated_product_sales.sql`
  (revenue by product/category).
- Gives a second `relationships` test pattern (`order_items.order_id →
  orders`, `order_items.product_id → products`) and an `accepted_values`
  example on `category`, beyond what the deck itself shows.

## Populate Scripts

- Pure SQL, using `generate_series` + deterministic `CASE`/modulo arithmetic
  to introduce dirtiness — no `random()`, so re-running always produces
  identical data (important: this is an answer key whose test results and
  aggregates must be stable/diffable).
- `01_create_schema_and_tables.sql`: `DROP SCHEMA IF EXISTS raw CASCADE;
  CREATE SCHEMA raw;` then `CREATE TABLE` for all 4 tables — idempotent,
  safe to re-run.
- `02_populate_raw_data.sql`: `INSERT ... SELECT ... FROM generate_series(...)`
  for all 4 tables, respecting FK order (customers/products before
  orders/order_items).
- `sql/README.md` documents: run once per trainee VM, before the training,
  via `psql -h localhost -U <user> -d <db> -f 01_create_schema_and_tables.sql`
  then `02_populate_raw_data.sql`.

## Tests & Docs

- Exactly the 4 generic tests (`unique`, `not_null`, `accepted_values`,
  `relationships`) on the core staging models, in the exact slide-50
  configuration, plus equivalent relationships tests on `order_items` in the
  bonus branch.
- `description` fields on all models and key columns (slides 52–53) so
  `dbt docs generate` produces a meaningful lineage graph mirroring slide 54,
  naturally extended by the bonus branch.

## Out of Scope

Seeds, snapshots, macros, Jinja beyond `ref()`/`source()`, incremental
models, packages/dbt-utils, CI/CD, deployment. These belong to the optional
Day 2, which is not yet built as a slide deck.

## Verification Plan

- `sql/*.sql` scripts run cleanly against a local Postgres 14 via `psql`,
  produce the expected row counts, and are idempotent (re-runnable).
- `reference-solution/` passes `dbt debug`, `dbt run`, `dbt test`, and
  `dbt docs generate` against that populated database.
- Curated model output spot-checked by hand for a couple of customers/
  products against the raw data.
