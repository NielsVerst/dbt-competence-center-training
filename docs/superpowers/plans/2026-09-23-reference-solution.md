# Day-1 Reference Solution & Raw Data Populate Scripts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Postgres populate SQL scripts and the answer-key dbt project for Day 1 of the "dbt voor het BI Competence Center" training, so trainees can diff their own hands-on work against a working reference.

**Architecture:** Two independent deliverables in one repo: (1) plain SQL scripts (`sql/`) that create a `raw` schema with 4 tables and fill them with deterministic, deliberately-dirty synthetic data using `generate_series`; (2) a dbt-core project (`reference-solution/`) with `source()` definitions pointing at that schema, staging models that clean the data, curated models that aggregate it, generic tests, and docs — mirroring the slide deck's core example (orders/customers) plus a clearly-marked bonus branch (products/order_items).

**Tech Stack:** PostgreSQL 14, dbt-core + dbt-postgres, plain SQL (no seeds/macros/packages). Verification during implementation uses a local Postgres 14 Docker container (`postgres:14`) and a throwaway Python venv with `dbt-core`+`dbt-postgres` installed — neither is part of the deliverable, both are for testing only.

**Spec:** `docs/superpowers/specs/2026-09-23-reference-solution-design.md`

## Global Constraints

- Postgres only, dbt-core only — no dbt Cloud, no packages/dbt-utils, no seeds/snapshots/macros/incremental models (Day 2 scope, not built).
- Populate scripts must be plain SQL runnable via any Postgres client (no Python/Faker dependency in the deliverable).
- Data generation must be deterministic (no `random()`) — re-running `02_populate_raw_data.sql` always produces identical rows.
- Core models/tests must match the slide deck exactly: `raw.orders(order_id, customer_id, order_date, status, amount)`, `raw.customers(customer_id, name, country)`, `stg_orders`, `stg_customers` (exact cleaning logic), `curated_customer_orders` (exact aggregation logic), the 4 generic tests in the deck's exact configuration.
- Bonus branch (products/order_items) must be clearly marked as "verdieping" / bonus in file headers and docs, separate from the core exercise.
- `dbt_project.yml` uses `name: 'ssc_ict_bi'`, `profile: 'ssc_ict_bi'`, `version: '1.0.0'` per slide 14.
- Staging models materialized as `view`, curated models as `table`, configured at the `dbt_project.yml` layer level (not per-model), per slide 14.

---

## File Structure

```
dbt-competence-center-training/
├── README.md                                    # modified
├── sql/
│   ├── 01_create_schema_and_tables.sql          # new
│   ├── 02_populate_raw_data.sql                 # new
│   └── README.md                                # new
└── reference-solution/
    ├── README.md                                # new
    ├── dbt_project.yml                          # new
    ├── profiles.yml.example                     # new
    └── models/
        ├── staging/
        │   ├── sources.yml                      # new
        │   ├── schema.yml                       # new
        │   ├── stg_orders.sql                   # new
        │   ├── stg_customers.sql                # new
        │   ├── stg_products.sql                 # new
        │   └── stg_order_items.sql              # new
        └── curated/
            ├── schema.yml                       # new
            ├── curated_customer_orders.sql      # new
            └── curated_product_sales.sql        # new
```

---

## Task 1: Verification environment (Postgres container + dbt venv)

Not a deliverable — throwaway infrastructure used to actually verify every later task against a real Postgres 14 + dbt-core, matching the trainee environment.

**Files:** none (Docker container + local venv, outside the repo)

- [ ] **Step 1: Start a disposable Postgres 14 container**

```bash
docker run -d --name dbt_training_verify -e POSTGRES_PASSWORD=training -e POSTGRES_USER=training -e POSTGRES_DB=training -p 55432:5432 postgres:14
```

- [ ] **Step 2: Wait for it to accept connections**

```bash
until docker exec dbt_training_verify pg_isready -U training >/dev/null 2>&1; do sleep 1; done; echo READY
```

Expected: prints `READY` within ~30s.

- [ ] **Step 3: Create a Python venv and install dbt-core + dbt-postgres**

```bash
python -m venv .superpowers/sdd/2026-09-23-reference-solution/verify_venv
.superpowers/sdd/2026-09-23-reference-solution/verify_venv/Scripts/python -m pip install --quiet dbt-core dbt-postgres
.superpowers/sdd/2026-09-23-reference-solution/verify_venv/Scripts/dbt --version
```

Expected: prints installed dbt-core/dbt-postgres versions, no errors.

No commit for this task — it's local verification tooling only.

---

## Task 2: `sql/01_create_schema_and_tables.sql` — raw schema DDL

**Files:**
- Create: `sql/01_create_schema_and_tables.sql`

**Interfaces:**
- Produces: `raw.customers(customer_id int, name text, country text)`, `raw.products(product_id int, product_name text, category text, unit_price numeric(10,2))`, `raw.orders(order_id int, customer_id int, order_date date, status text, amount numeric(10,2))`, `raw.order_items(order_item_id int, order_id int, product_id int, quantity int, unit_price numeric(10,2))` — all in schema `raw`. Column names/types match slide 37 for `orders`/`customers` exactly (note: `order_date`/`amount` are stored as loosely-typed `date`/`numeric` here since this is meant to feel like a raw landing zone — the staging layer is what does the authoritative casting per slide 39-40).

- [ ] **Step 1: Write the DDL script**

```sql
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
```

- [ ] **Step 2: Run it against the verification container and confirm the tables exist**

```bash
docker exec -i dbt_training_verify psql -U training -d training < sql/01_create_schema_and_tables.sql
docker exec dbt_training_verify psql -U training -d training -c "\dt raw.*"
```

Expected: 4 tables listed (`customers`, `orders`, `products`, `order_items`).

- [ ] **Step 3: Confirm idempotency by running it twice**

```bash
docker exec -i dbt_training_verify psql -U training -d training < sql/01_create_schema_and_tables.sql
docker exec -i dbt_training_verify psql -U training -d training < sql/01_create_schema_and_tables.sql
```

Expected: both runs succeed with no errors (no "already exists" failures).

- [ ] **Step 4: Commit**

```bash
git add sql/01_create_schema_and_tables.sql
git commit -m "Add raw schema DDL for training populate scripts"
```

---

## Task 3: `sql/02_populate_raw_data.sql` — deterministic dirty synthetic data

**Files:**
- Create: `sql/02_populate_raw_data.sql`

**Interfaces:**
- Consumes: the 4 tables from Task 2 (`raw.customers`, `raw.products`, `raw.orders`, `raw.order_items`).
- Produces: ~120 rows in `raw.customers`, ~40 rows in `raw.products`, ~500 rows in `raw.orders`, ~1500 rows in `raw.order_items`. All FK-consistent (`orders.customer_id` always exists in `customers`, `order_items.order_id`/`product_id` always exist in `orders`/`products`). `orders.status` cycles deterministically through `'Shipped'`, `'OPEN'`, `'shipped'`, `'cancelled'`, `'Cancelled'` (mixed case, matching slide 37's teaching point). `customers.name`/`country` and `products.product_name`/`category` have deterministic inconsistent spacing/casing.

- [ ] **Step 1: Write the populate script**

```sql
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
```

- [ ] **Step 2: Run against the verification container (fresh schema first)**

```bash
docker exec -i dbt_training_verify psql -U training -d training < sql/01_create_schema_and_tables.sql
docker exec -i dbt_training_verify psql -U training -d training < sql/02_populate_raw_data.sql
```

Expected: no errors; each `INSERT` reports the expected row count (`INSERT 0 120`, `INSERT 0 40`, `INSERT 0 500`, `INSERT 0 1500`).

- [ ] **Step 3: Verify row counts, dirtiness, and FK consistency with queries**

```bash
docker exec dbt_training_verify psql -U training -d training -c "
SELECT
  (SELECT count(*) FROM raw.customers) AS customers,
  (SELECT count(*) FROM raw.products) AS products,
  (SELECT count(*) FROM raw.orders) AS orders,
  (SELECT count(*) FROM raw.order_items) AS order_items;
"
docker exec dbt_training_verify psql -U training -d training -c "SELECT DISTINCT status FROM raw.orders ORDER BY 1;"
docker exec dbt_training_verify psql -U training -d training -c "
SELECT count(*) FROM raw.orders o LEFT JOIN raw.customers c USING (customer_id) WHERE c.customer_id IS NULL;
"
docker exec dbt_training_verify psql -U training -d training -c "
SELECT count(*) FROM raw.order_items oi
LEFT JOIN raw.orders o ON o.order_id = oi.order_id
LEFT JOIN raw.products p ON p.product_id = oi.product_id
WHERE o.order_id IS NULL OR p.product_id IS NULL;
"
```

Expected: counts are 120/40/500/1500; `status` shows exactly the 5 mixed-case variants (`Shipped`, `OPEN`, `shipped`, `cancelled`, `Cancelled`); both orphan-check queries return `0`.

- [ ] **Step 4: Confirm determinism by truncating and re-running**

```bash
docker exec dbt_training_verify psql -U training -d training -c "TRUNCATE raw.customers, raw.products, raw.orders, raw.order_items CASCADE;"
docker exec -i dbt_training_verify psql -U training -d training < sql/02_populate_raw_data.sql
docker exec dbt_training_verify psql -U training -d training -c "SELECT md5(string_agg(status, ',' ORDER BY order_id)) FROM raw.orders;"
```

Run the same `md5(...)` query a second time after another truncate+repopulate cycle and confirm the hash is identical both times.

- [ ] **Step 5: Commit**

```bash
git add sql/02_populate_raw_data.sql
git commit -m "Add deterministic populate script for raw training data"
```

---

## Task 4: `sql/README.md` — populate scripts usage doc

**Files:**
- Create: `sql/README.md`

- [ ] **Step 1: Write the doc**

```markdown
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

Both scripts are idempotent — `01_create_schema_and_tables.sql` drops and
recreates the `raw` schema, and `02_populate_raw_data.sql` inserts a fixed,
deterministic dataset (no randomness), so re-running them always produces
identical data. If you need to reset your environment mid-training, just
run both scripts again in order.

## What gets created

- `raw.customers` (~120 rows) and `raw.orders` (~500 rows) — the two tables
  used throughout the core Day 1 exercises, with deliberately inconsistent
  casing/spacing (e.g. order `status` values like `Shipped`/`OPEN`/`shipped`)
  that you'll clean up in the staging layer.
- `raw.products` (~40 rows) and `raw.order_items` (~1500 rows) — a bonus
  "verdieping" domain for exploring beyond the core exercise, once you've
  finished the guided exercises. Not required for the core hands-on tasks.
```

- [ ] **Step 2: Commit**

```bash
git add sql/README.md
git commit -m "Document how to run the raw data populate scripts"
```

---

## Task 5: `reference-solution/dbt_project.yml` + `profiles.yml.example`

**Files:**
- Create: `reference-solution/dbt_project.yml`
- Create: `reference-solution/profiles.yml.example`

**Interfaces:**
- Produces: project name/profile `ssc_ict_bi`, layer materializations (`staging` → `view`, `curated` → `table`) that all later model tasks rely on implicitly (no per-model `{{ config(...) }}` needed).

- [ ] **Step 1: Write `dbt_project.yml`**

```yaml
name: 'ssc_ict_bi'
version: '1.0.0'
config-version: 2

profile: 'ssc_ict_bi'

model-paths: ["models"]
clean-targets:
  - "target"
  - "dbt_packages"

models:
  ssc_ict_bi:
    staging:
      +materialized: view
    curated:
      +materialized: table
```

- [ ] **Step 2: Write `profiles.yml.example`**

```yaml
# Copy this to ~/.dbt/profiles.yml (or set DBT_PROFILES_DIR to this folder)
# and fill in your own Postgres credentials. The real profiles.yml is
# gitignored — never commit real credentials.

ssc_ict_bi:
  target: postgres
  outputs:
    postgres:
      type: postgres
      host: localhost
      port: 5432
      user: <your_postgres_user>
      password: <your_postgres_password>
      dbname: <your_database>
      schema: dbt_reference_solution
      threads: 4
```

- [ ] **Step 3: Commit**

```bash
git add reference-solution/dbt_project.yml reference-solution/profiles.yml.example
git commit -m "Add reference-solution dbt project scaffold"
```

(No standalone test here — Task 6 verifies `dbt debug` against these files once `sources.yml` exists too. `models/` doesn't exist yet, which is fine; `dbt_project.yml` doesn't require it to be non-empty.)

---

## Task 6: `reference-solution/models/staging/sources.yml`

**Files:**
- Create: `reference-solution/models/staging/sources.yml`

**Interfaces:**
- Produces: `source('raw', 'orders')`, `source('raw', 'customers')`, `source('raw', 'products')`, `source('raw', 'order_items')` — used by Task 7's staging models.

- [ ] **Step 1: Write `sources.yml`**

```yaml
version: 2

sources:
  - name: raw
    schema: raw
    description: >
      Raw landing tables, loaded as-is with no transformation. Read-only —
      dbt never writes here, only reads via source().
    tables:
      - name: orders
        description: Raw order records, one row per order.
      - name: customers
        description: Raw customer records, one row per customer.
      - name: products
        description: "Verdieping: raw product catalog, one row per product."
      - name: order_items
        description: "Verdieping: raw order line items, one row per item."
```

- [ ] **Step 2: Set up a real profiles dir for the venv and run `dbt debug`**

```bash
mkdir -p .superpowers/sdd/2026-09-23-reference-solution/dbt_profiles
cat > .superpowers/sdd/2026-09-23-reference-solution/dbt_profiles/profiles.yml <<'EOF'
ssc_ict_bi:
  target: postgres
  outputs:
    postgres:
      type: postgres
      host: localhost
      port: 55432
      user: training
      password: training
      dbname: training
      schema: dbt_reference_solution
      threads: 4
EOF
DBT_PROFILES_DIR=.superpowers/sdd/2026-09-23-reference-solution/dbt_profiles .superpowers/sdd/2026-09-23-reference-solution/verify_venv/Scripts/dbt debug --project-dir reference-solution
```

(This verification copy points at the Docker container from Task 1, which maps container port 5432 to host port 55432 — it is deliberately different from `profiles.yml.example`'s shipped `port: 5432`, which targets a trainee's own local Postgres.)

Expected: `All checks passed!`

- [ ] **Step 3: Confirm the sources are visible**

```bash
DBT_PROFILES_DIR=.superpowers/sdd/2026-09-23-reference-solution/dbt_profiles .superpowers/sdd/2026-09-23-reference-solution/verify_venv/Scripts/dbt show --inline "select * from {{ source('raw', 'customers') }} limit 5" --profiles-dir .superpowers/sdd/2026-09-23-reference-solution/dbt_profiles --project-dir reference-solution
```

Expected: 5 rows of customer data printed, no errors.

- [ ] **Step 4: Commit**

```bash
git add reference-solution/models/staging/sources.yml
git commit -m "Add source definitions for raw schema"
```

---

## Task 7: Staging models — `stg_orders.sql`, `stg_customers.sql`

**Files:**
- Create: `reference-solution/models/staging/stg_orders.sql`
- Create: `reference-solution/models/staging/stg_customers.sql`

**Interfaces:**
- Consumes: `source('raw', 'orders')`, `source('raw', 'customers')` from Task 6.
- Produces: `ref('stg_orders')` → columns `order_id, customer_id, order_date, order_status, order_amount`; `ref('stg_customers')` → columns `customer_id, customer_name, country_code`. Both relied on by Task 9's `curated_customer_orders.sql` and Task 8's `schema.yml` tests.

- [ ] **Step 1: Write `stg_orders.sql`** (exact logic from slide 39)

```sql
with source as (
    select * from {{ source('raw', 'orders') }}
)

select
    order_id,
    customer_id,
    cast(order_date as date) as order_date,
    lower(status) as order_status,
    amount::numeric(10,2) as order_amount
from source
```

- [ ] **Step 2: Write `stg_customers.sql`** (exact logic from slide 40)

```sql
with source as (
    select * from {{ source('raw', 'customers') }}
)

select
    customer_id,
    trim(name) as customer_name,
    upper(country) as country_code
from source
```

- [ ] **Step 3: Run both models and inspect output**

```bash
DBT_PROFILES_DIR=.superpowers/sdd/2026-09-23-reference-solution/dbt_profiles .superpowers/sdd/2026-09-23-reference-solution/verify_venv/Scripts/dbt run --select staging --profiles-dir .superpowers/sdd/2026-09-23-reference-solution/dbt_profiles --project-dir reference-solution
```

Expected: `Completed successfully`, 2 views created (`stg_orders`, `stg_customers` — note: `stg_products`/`stg_order_items` don't exist yet, that's fine, `--select staging` only runs what's there).

```bash
docker exec dbt_training_verify psql -U training -d training -c "SELECT DISTINCT order_status FROM dbt_reference_solution.stg_orders ORDER BY 1;"
docker exec dbt_training_verify psql -U training -d training -c "SELECT DISTINCT country_code FROM dbt_reference_solution.stg_customers ORDER BY 1;"
```

Expected: `order_status` shows only `shipped`, `open`, `cancelled` (all lowercase, deduped from the 5 mixed-case raw variants); `country_code` shows only `NL` (deduped and uppercased, trimmed).

- [ ] **Step 4: Commit**

```bash
git add reference-solution/models/staging/stg_orders.sql reference-solution/models/staging/stg_customers.sql
git commit -m "Add core staging models (stg_orders, stg_customers)"
```

---

## Task 8: `reference-solution/models/staging/schema.yml` — tests + descriptions

**Files:**
- Create: `reference-solution/models/staging/schema.yml`

**Interfaces:**
- Consumes: `stg_orders`, `stg_customers` from Task 7.

- [ ] **Step 1: Write `schema.yml`** (exact test configuration from slide 50, plus descriptions)

```yaml
version: 2

models:
  - name: stg_orders
    description: One row per order, cleaned: status lowercased, amount cast to numeric(10,2).
    columns:
      - name: order_id
        description: Primary key of the order.
        tests:
          - unique
          - not_null
      - name: customer_id
        description: Foreign key to stg_customers.
        tests:
          - relationships:
              to: ref('stg_customers')
              field: customer_id
      - name: order_status
        description: Order status, lowercased (e.g. 'shipped', 'open', 'cancelled').
        tests:
          - accepted_values:
              values: ['open', 'shipped', 'cancelled']

  - name: stg_customers
    description: One row per customer, cleaned: name trimmed, country uppercased into country_code.
    columns:
      - name: customer_id
        description: Primary key of the customer.
        tests:
          - unique
          - not_null
```

- [ ] **Step 2: Run tests**

```bash
DBT_PROFILES_DIR=.superpowers/sdd/2026-09-23-reference-solution/dbt_profiles .superpowers/sdd/2026-09-23-reference-solution/verify_venv/Scripts/dbt test --select staging --profiles-dir .superpowers/sdd/2026-09-23-reference-solution/dbt_profiles --project-dir reference-solution
```

Expected: all tests `PASS`. If `accepted_values` on `order_status` fails, check Task 3's status cycling — it must only produce values that lowercase to `open`/`shipped`/`cancelled`.

- [ ] **Step 3: Commit**

```bash
git add reference-solution/models/staging/schema.yml
git commit -m "Add generic tests and descriptions for core staging models"
```

---

## Task 9: Curated model — `curated_customer_orders.sql`

**Files:**
- Create: `reference-solution/models/curated/curated_customer_orders.sql`

**Interfaces:**
- Consumes: `ref('stg_orders')`, `ref('stg_customers')` from Task 7.
- Produces: `curated_customer_orders` table with columns `customer_id, customer_name, aantal_orders, totale_omzet`.

- [ ] **Step 1: Write the model** (exact logic from slide 42)

```sql
with orders as (
    select * from {{ ref('stg_orders') }}
),

customers as (
    select * from {{ ref('stg_customers') }}
)

select
    c.customer_id,
    c.customer_name,
    count(o.order_id) as aantal_orders,
    sum(o.order_amount) as totale_omzet
from orders o
join customers c using (customer_id)
group by 1, 2
```

- [ ] **Step 2: Run it and spot-check aggregates**

```bash
DBT_PROFILES_DIR=.superpowers/sdd/2026-09-23-reference-solution/dbt_profiles .superpowers/sdd/2026-09-23-reference-solution/verify_venv/Scripts/dbt run --select curated_customer_orders --profiles-dir .superpowers/sdd/2026-09-23-reference-solution/dbt_profiles --project-dir reference-solution
```

Expected: `Completed successfully`, table `curated_customer_orders` created.

```bash
docker exec dbt_training_verify psql -U training -d training -c "SELECT * FROM dbt_reference_solution.curated_customer_orders ORDER BY customer_id LIMIT 5;"
docker exec dbt_training_verify psql -U training -d training -c "
SELECT count(*), sum(order_amount) FROM dbt_reference_solution.stg_orders WHERE customer_id = 101;
"
docker exec dbt_training_verify psql -U training -d training -c "
SELECT aantal_orders, totale_omzet FROM dbt_reference_solution.curated_customer_orders WHERE customer_id = 101;
"
```

Expected: the manual count/sum for `customer_id = 101` from `stg_orders` matches `aantal_orders`/`totale_omzet` for the same customer in `curated_customer_orders` exactly.

- [ ] **Step 3: Commit**

```bash
git add reference-solution/models/curated/curated_customer_orders.sql
git commit -m "Add curated_customer_orders aggregation model"
```

---

## Task 10: Bonus staging models — `stg_products.sql`, `stg_order_items.sql`

**Files:**
- Create: `reference-solution/models/staging/stg_products.sql`
- Create: `reference-solution/models/staging/stg_order_items.sql`

**Interfaces:**
- Consumes: `source('raw', 'products')`, `source('raw', 'order_items')` from Task 6.
- Produces: `ref('stg_products')` → `product_id, product_name, category, unit_price`; `ref('stg_order_items')` → `order_item_id, order_id, product_id, quantity, unit_price`. Relied on by Task 11.

- [ ] **Step 1: Write `stg_products.sql`**

```sql
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
```

- [ ] **Step 2: Write `stg_order_items.sql`**

```sql
-- Verdieping / bonus: not part of the core Day 1 exercise.
with source as (
    select * from {{ source('raw', 'order_items') }}
)

select
    order_item_id,
    order_id,
    product_id,
    quantity,
    unit_price::numeric(10,2) as unit_price
from source
```

- [ ] **Step 3: Run and inspect**

```bash
DBT_PROFILES_DIR=.superpowers/sdd/2026-09-23-reference-solution/dbt_profiles .superpowers/sdd/2026-09-23-reference-solution/verify_venv/Scripts/dbt run --select stg_products stg_order_items --profiles-dir .superpowers/sdd/2026-09-23-reference-solution/dbt_profiles --project-dir reference-solution
docker exec dbt_training_verify psql -U training -d training -c "SELECT DISTINCT category FROM dbt_reference_solution.stg_products ORDER BY 1;"
```

Expected: `Completed successfully`; `category` shows only `electronics`, `home` (deduped/lowercased from the 4 mixed-case raw variants).

- [ ] **Step 4: Commit**

```bash
git add reference-solution/models/staging/stg_products.sql reference-solution/models/staging/stg_order_items.sql
git commit -m "Add bonus staging models (stg_products, stg_order_items)"
```

---

## Task 11: Bonus curated model — `curated_product_sales.sql`

**Files:**
- Create: `reference-solution/models/curated/curated_product_sales.sql`

**Interfaces:**
- Consumes: `ref('stg_products')`, `ref('stg_order_items')` from Task 10.
- Produces: `curated_product_sales` table with columns `product_id, product_name, category, units_sold, totale_omzet`.

- [ ] **Step 1: Write the model**

```sql
-- Verdieping / bonus: not part of the core Day 1 exercise.
with items as (
    select * from {{ ref('stg_order_items') }}
),

products as (
    select * from {{ ref('stg_products') }}
)

select
    p.product_id,
    p.product_name,
    p.category,
    sum(i.quantity) as units_sold,
    sum(i.quantity * i.unit_price) as totale_omzet
from items i
join products p using (product_id)
group by 1, 2, 3
```

- [ ] **Step 2: Run it and spot-check**

```bash
DBT_PROFILES_DIR=.superpowers/sdd/2026-09-23-reference-solution/dbt_profiles .superpowers/sdd/2026-09-23-reference-solution/verify_venv/Scripts/dbt run --select curated_product_sales --profiles-dir .superpowers/sdd/2026-09-23-reference-solution/dbt_profiles --project-dir reference-solution
docker exec dbt_training_verify psql -U training -d training -c "SELECT * FROM dbt_reference_solution.curated_product_sales ORDER BY product_id LIMIT 5;"
```

Expected: `Completed successfully`; rows show plausible `units_sold`/`totale_omzet` values (non-null, non-negative).

- [ ] **Step 3: Commit**

```bash
git add reference-solution/models/curated/curated_product_sales.sql
git commit -m "Add bonus curated_product_sales aggregation model"
```

---

## Task 12: `reference-solution/models/curated/schema.yml` — tests + descriptions

**Files:**
- Create: `reference-solution/models/curated/schema.yml`
- Modify: `reference-solution/models/staging/schema.yml` (append two new entries under the existing top-level `models:` key, as siblings of the `stg_orders`/`stg_customers` entries Task 8 wrote — do not create a second `models:` key, and do not remove or reorder Task 8's entries)

**Interfaces:**
- Consumes: `curated_customer_orders` (Task 9), `curated_product_sales` (Task 11), the `stg_products`/`stg_order_items` file from Task 10, and the existing `reference-solution/models/staging/schema.yml` written by Task 8.

- [ ] **Step 1: Write `schema.yml`** (curated descriptions match slide 53's pattern; bonus tests exercise `relationships`/`accepted_values` beyond the deck)

```yaml
version: 2

models:
  - name: curated_customer_orders
    description: One row per customer with order count and total revenue. Report-ready.
    columns:
      - name: customer_id
        description: Primary key of the customer.
        tests:
          - unique
          - not_null
      - name: totale_omzet
        description: Total revenue (sum of order_amount) across all of this customer's orders.

  - name: curated_product_sales
    description: "Verdieping: one row per product with units sold and total revenue."
    columns:
      - name: product_id
        description: Primary key of the product.
        tests:
          - unique
          - not_null
      - name: category
        tests:
          - accepted_values:
              values: ['electronics', 'home']
```

- [ ] **Step 2: Add bonus relationships tests to staging schema.yml for order_items**

This extends Task 8's file — append to `reference-solution/models/staging/schema.yml`:

```yaml
  - name: stg_products
    description: "Verdieping: one row per product, cleaned: name trimmed, category lowercased."
    columns:
      - name: product_id
        description: Primary key of the product.
        tests:
          - unique
          - not_null

  - name: stg_order_items
    description: "Verdieping: one row per order line item."
    columns:
      - name: order_item_id
        description: Primary key of the order line item.
        tests:
          - unique
          - not_null
      - name: order_id
        tests:
          - relationships:
              to: ref('stg_orders')
              field: order_id
      - name: product_id
        tests:
          - relationships:
              to: ref('stg_products')
              field: product_id
```

- [ ] **Step 3: Run full build and confirm all tests pass**

```bash
DBT_PROFILES_DIR=.superpowers/sdd/2026-09-23-reference-solution/dbt_profiles .superpowers/sdd/2026-09-23-reference-solution/verify_venv/Scripts/dbt build --profiles-dir .superpowers/sdd/2026-09-23-reference-solution/dbt_profiles --project-dir reference-solution
```

Expected: all models build, all tests `PASS`, `Completed successfully`. This is the full end-to-end verification of the whole project.

- [ ] **Step 4: Commit**

```bash
git add reference-solution/models/curated/schema.yml reference-solution/models/staging/schema.yml
git commit -m "Add tests and descriptions for bonus models"
```

---

## Task 13: Docs generation check + `reference-solution/README.md`

**Files:**
- Create: `reference-solution/README.md`

- [ ] **Step 1: Generate docs and confirm the site builds**

```bash
DBT_PROFILES_DIR=.superpowers/sdd/2026-09-23-reference-solution/dbt_profiles .superpowers/sdd/2026-09-23-reference-solution/verify_venv/Scripts/dbt docs generate --profiles-dir .superpowers/sdd/2026-09-23-reference-solution/dbt_profiles --project-dir reference-solution
```

Expected: `Completed successfully`, `reference-solution/target/catalog.json` and `reference-solution/target/manifest.json` are created (don't commit these — they're covered by the existing `target/` gitignore rule).

```bash
ls reference-solution/target/catalog.json reference-solution/target/manifest.json
```

Expected: both files exist.

- [ ] **Step 2: Write `reference-solution/README.md`**

```markdown
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
```

- [ ] **Step 3: Commit**

```bash
git add reference-solution/README.md
git commit -m "Add reference-solution README"
```

---

## Task 14: Update top-level `README.md`

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Rewrite the README to explain the repo layout**

```markdown
# dbt-competence-center-training

Repository for setting up your own dbt project in this training.

## Layout

- `sql/` — SQL scripts to populate your own Postgres `raw` schema before
  the training starts. See `sql/README.md`.
- `reference-solution/` — the instructor's completed answer-key dbt project
  for Day 1. Not the starting point for the exercises — see
  `reference-solution/README.md`.

During the hands-on exercises, you'll create your own dbt project in this
repo (or alongside it) with `dbt init`, following the trainer's
instructions.
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "Document repo layout in top-level README"
```

---

## Task 15: Full end-to-end re-verification + teardown

**Files:** none (verification only)

- [ ] **Step 1: Fresh-database full run** — proves the whole pipeline works from a clean Postgres, exactly as a trainee's first run would

```bash
docker exec dbt_training_verify psql -U training -d training -c "DROP SCHEMA IF EXISTS raw CASCADE; DROP SCHEMA IF EXISTS dbt_reference_solution CASCADE;"
docker exec -i dbt_training_verify psql -U training -d training < sql/01_create_schema_and_tables.sql
docker exec -i dbt_training_verify psql -U training -d training < sql/02_populate_raw_data.sql
DBT_PROFILES_DIR=.superpowers/sdd/2026-09-23-reference-solution/dbt_profiles .superpowers/sdd/2026-09-23-reference-solution/verify_venv/Scripts/dbt build --profiles-dir .superpowers/sdd/2026-09-23-reference-solution/dbt_profiles --project-dir reference-solution
DBT_PROFILES_DIR=.superpowers/sdd/2026-09-23-reference-solution/dbt_profiles .superpowers/sdd/2026-09-23-reference-solution/verify_venv/Scripts/dbt docs generate --profiles-dir .superpowers/sdd/2026-09-23-reference-solution/dbt_profiles --project-dir reference-solution
```

Expected: everything succeeds with no manual fixes needed, `dbt build` shows 6 models built and all tests passed (`stg_orders`, `stg_customers`, `stg_products`, `stg_order_items`, `curated_customer_orders`, `curated_product_sales`).

- [ ] **Step 2: Tear down verification infrastructure**

```bash
docker rm -f dbt_training_verify
rm -rf .superpowers/sdd/2026-09-23-reference-solution/verify_venv .superpowers/sdd/2026-09-23-reference-solution/dbt_profiles
```

- [ ] **Step 3: Confirm git status is clean (only intended files tracked, target/ etc. ignored)**

```bash
git status
git log --oneline -15
```

Expected: working tree clean, all 12+ commits from this plan present, no `target/`, `dbt_packages/`, or `profiles.yml` accidentally tracked.
