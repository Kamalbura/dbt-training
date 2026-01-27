# What is dbt?

## The Problem dbt Solves

Imagine you work at a company with a data warehouse. You need to:

1. Take raw data from various sources (CRM, website, payments...)
2. Clean and transform it
3. Create tables for analysts to use
4. Make sure the data is correct
5. Document what everything means

**Before dbt, people would:**
- Write SQL scripts and run them manually
- Schedule scripts with cron jobs
- Hope the order was correct
- Have no idea if the data was right
- Forget what tables meant

**dbt fixes all of this.**

---

## dbt in One Sentence

> dbt (data build tool) transforms raw data in your warehouse into analytics-ready tables using SQL files that are version-controlled, tested, and documented.

---

## The dbt Philosophy

### 1. SQL is All You Need

You don't need to learn Python, Spark, or complex ETL tools. If you know SQL, you can use dbt.

```sql
-- This is a complete dbt model
SELECT
  customer_id,
  email,
  DATE(created_at) AS signup_date
FROM raw_customers
WHERE email IS NOT NULL
```

### 2. Analytics as Software Engineering

dbt brings software engineering practices to analytics:

| Practice | How dbt Implements It |
|----------|----------------------|
| Version control | SQL files in Git |
| Testing | Built-in test framework |
| Documentation | Auto-generated docs |
| Modularity | Models reference other models |
| CI/CD | Run dbt in pipelines |

### 3. ELT, Not ETL

**ETL (Extract-Transform-Load):**
```
Source → Transform (separate system) → Load into Warehouse
```

**ELT (Extract-Load-Transform):**
```
Source → Load into Warehouse → Transform (inside warehouse)
```

dbt does the **T** in ELT. The warehouse does the heavy lifting.

---

## How dbt Works (The Flow)

```
┌─────────────────┐
│ Your SQL Files  │  (models/*.sql)
│ + Jinja         │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ dbt compile     │  Converts Jinja to SQL
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ dbt run         │  Runs SQL in your warehouse
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Tables/Views    │  In BigQuery (saras-bigquery.dbt_training.*)
│ created         │
└─────────────────┘
```

---

## What You Already Did (Explained)

Let's trace through what happened when you ran your commands:

### Step 1: dbt debug

```powershell
dbt debug
```

**What happened:**
1. dbt read `dbt_project.yml` (found your project config)
2. dbt looked for `profiles.yml` (found connection settings)
3. dbt tried connecting to BigQuery (succeeded!)
4. dbt reported "All checks passed!"

### Step 2: dbt seed

```powershell
dbt seed --select example_customers
```

**What happened:**
1. dbt found `seeds/example_customers.csv`
2. dbt created a table in BigQuery: `saras-bigquery.dbt_training.example_customers`
3. dbt uploaded the 3 rows from your CSV

**The SQL dbt ran internally (simplified):**
```sql
CREATE TABLE `saras-bigquery.dbt_training.example_customers` (
  id INT64,
  name STRING,
  email STRING,
  signup_date DATE
);

INSERT INTO `saras-bigquery.dbt_training.example_customers`
VALUES
  (1, 'Alice', 'alice@example.com', '2023-01-05'),
  (2, 'Bob', 'bob@example.com', '2023-02-10'),
  (3, 'Charlie', 'charlie@example.com', '2023-03-15');
```

### Step 3: dbt run

```powershell
dbt run --select customers_from_seed
```

**Your model file** (`models/example/customers_from_seed.sql`):
```sql
{{ config(materialized='table') }}

select *
from {{ ref('example_customers') }}
```

**What dbt did:**
1. Read your SQL file
2. Saw `{{ ref('example_customers') }}` → replaced with actual table name
3. Saw `{{ config(materialized='table') }}` → knew to create a TABLE, not a view
4. Compiled and ran this SQL:

```sql
CREATE OR REPLACE TABLE `saras-bigquery.dbt_training.customers_from_seed` AS
SELECT *
FROM `saras-bigquery.dbt_training.example_customers`
```

### Step 4: dbt test

```powershell
dbt test --select example_customers
```

**Your schema file** (`seeds/schema.yml`):
```yaml
seeds:
  - name: example_customers
    columns:
      - name: id
        tests:
          - unique
          - not_null
      - name: email
        tests:
          - not_null
```

**What dbt did:**

For `unique` test on `id`:
```sql
SELECT id
FROM `saras-bigquery.dbt_training.example_customers`
GROUP BY id
HAVING COUNT(*) > 1
```
If this returns 0 rows → PASS (no duplicates)

For `not_null` test on `id`:
```sql
SELECT id
FROM `saras-bigquery.dbt_training.example_customers`
WHERE id IS NULL
```
If this returns 0 rows → PASS (no nulls)

---

## Key Concepts Preview

| Concept | What It Is | Example |
|---------|------------|---------|
| **Model** | A SQL file that becomes a table/view | `customers_from_seed.sql` |
| **ref()** | Function to reference another model | `{{ ref('example_customers') }}` |
| **Materialization** | How to build the model (table/view/etc.) | `{{ config(materialized='table') }}` |
| **Seed** | CSV file loaded into warehouse | `example_customers.csv` |
| **Test** | Assertion about your data | `unique`, `not_null` |
| **Profile** | Connection settings | `profiles.yml` |

---

## dbt Cloud vs dbt Core

| Feature | dbt Core (What You're Using) | dbt Cloud |
|---------|------------------------------|-----------|
| Price | Free | Free tier + paid plans |
| Runs where | Your computer (via terminal) | Cloud servers |
| IDE | VS Code + terminal | Web-based IDE |
| Scheduling | You set up (cron, Airflow, etc.) | Built-in scheduler |
| Best for | Learning, local dev | Production, teams |

You initialized your project in dbt Cloud (which created the repo structure), then cloned it locally to use dbt Core.

---

## The dbt Workflow

```
1. WRITE       →  2. TEST       →  3. DEPLOY
   SQL models      dbt test         dbt run (production)
   in VS Code      locally          scheduled
```

**Your daily workflow will be:**
1. Edit SQL files
2. Run `dbt run` to build
3. Run `dbt test` to verify
4. Commit to Git
5. (In production) dbt runs on a schedule

---

## Summary

- dbt transforms raw data into analytics-ready tables
- You write SQL + Jinja, dbt handles the rest
- dbt brings version control, testing, and docs to analytics
- You already ran the full workflow: seed → run → test

---

**Next:** [02_dbt_project_structure.md](02_dbt_project_structure.md)
