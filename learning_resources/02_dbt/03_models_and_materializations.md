# Models and Materializations

## What is a Model?

A **model** is a SQL SELECT statement saved as a `.sql` file in the `models/` folder.

When you run `dbt run`, dbt turns that SELECT into a table or view in your warehouse.

---

## Anatomy of a Model

```sql
-- models/example/customers_from_seed.sql

{{ config(materialized='table') }}  -- Config block (optional)

-- Comments explaining the model
-- This model selects all customers from our seed file

select *
from {{ ref('example_customers') }}  -- Reference another model/seed
```

**Three parts:**
1. **Config block** (optional) - Settings for this model
2. **Comments** - Documentation within the file
3. **SELECT statement** - The actual transformation

---

## Materializations Explained

**Materialization** = How dbt builds the model in data warehouse.

### The Four Materializations

| Type | What It Creates | Data Stored? | Rebuilt Every Run? |
|------|-----------------|--------------|-------------------|
| `view` | SQL View | No (query saved) | Yes (recreated) |
| `table` | Physical Table | Yes | Yes (dropped & recreated) |
| `incremental` | Physical Table | Yes | Only new/changed rows |
| `ephemeral` | Nothing (CTE) | No | N/A (inlined) |

---

### 1. View (Default)

```sql
{{ config(materialized='view') }}

select * from {{ ref('raw_customers') }}
```

**What dbt runs:**
```sql
CREATE VIEW customers_view AS
SELECT * FROM raw_customers;
```

**Pros:**
- No storage cost
- Always shows latest data

**Cons:**
- Query runs every time someone reads from it
- Can be slow for complex logic

**Best for:**
- Light transformations
- Development/testing
- Small datasets

---

### 2. Table

```sql
{{ config(materialized='table') }}

select * from {{ ref('raw_customers') }}
```

**What dbt runs:**
```sql
CREATE OR REPLACE TABLE customers_table AS
SELECT * FROM raw_customers;
```

**Pros:**
- Fast to query (data pre-computed)
- Consistent results

**Cons:**
- Storage cost
- Full rebuild every run (can be slow for large tables)

**Best for:**
- Final tables used by analysts
- Complex transformations
- Small to medium datasets

---

### 3. Incremental

```sql
{{ config(materialized='incremental') }}

select *
from {{ ref('raw_events') }}

{% if is_incremental() %}
  where event_date > (select max(event_date) from {{ this }})
{% endif %}
```

**What dbt runs (first time):**
```sql
CREATE TABLE events_incremental AS
SELECT * FROM raw_events;
```

**What dbt runs (subsequent times):**
```sql
INSERT INTO events_incremental
SELECT * FROM raw_events
WHERE event_date > (SELECT MAX(event_date) FROM events_incremental);
```

**Pros:**
- Fast for large tables
- Lower cost (less data processed)

**Cons:**
- More complex logic
- Need to handle updates/deletes carefully

**Best for:**
- Large fact tables
- Append-only data (logs, events)
- Tables that grow over time

---

### 4. Ephemeral

```sql
{{ config(materialized='ephemeral') }}

select * from {{ ref('raw_customers') }}
```

**What dbt does:**
- Doesn't create any table or view
- Injects the SQL as a CTE into downstream models

**Example:**

`models/ephemeral_model.sql`:
```sql
{{ config(materialized='ephemeral') }}
select id, upper(name) as name from raw_customers
```

`models/final_model.sql`:
```sql
select * from {{ ref('ephemeral_model') }}
```

**Compiled SQL of final_model:**
```sql
WITH ephemeral_model AS (
  SELECT id, UPPER(name) AS name FROM raw_customers
)
SELECT * FROM ephemeral_model
```

**Pros:**
- No storage cost
- Good for reusable logic

**Cons:**
- Can't query directly
- Logic is duplicated in every downstream model

**Best for:**
- Intermediate transformations
- Logic used by multiple models

---

## Setting Materializations

### Method 1: In the Model File

```sql
{{ config(materialized='table') }}

select * from source
```

### Method 2: In dbt_project.yml (for folders)

```yaml
models:
  my_project:
    staging:
      +materialized: view      # All staging models are views
    marts:
      +materialized: table     # All marts are tables
```

### Method 3: In schema.yml

```yaml
models:
  - name: my_model
    config:
      materialized: table
```

**Precedence (highest to lowest):**
1. In-file config block
2. schema.yml
3. dbt_project.yml

---

## The Config Block

Common configurations:

```sql
{{
  config(
    materialized='table',
    schema='analytics',           # Override default schema
    alias='cust',                 # Table name (instead of filename)
    tags=['daily', 'important'],  # For selection
    enabled=true,                 # true/false to skip
    persist_docs={'relation': true}  # Keep docs in warehouse
  )
}}
```

### BigQuery-Specific Config

```sql
{{
  config(
    materialized='table',
    partition_by={
      "field": "created_date",
      "data_type": "date"
    },
    cluster_by=['customer_id']
  )
}}
```

---

## How to Choose a Materialization

```
Is this used by downstream models?
├── No → Is it complex/slow?
│   ├── No → view
│   └── Yes → table
└── Yes → Is it large (>1M rows)?
    ├── No → table
    └── Yes → Does it have a reliable timestamp?
        ├── Yes → incremental
        └── No → table (with partitioning)
```

### Quick Rules

| Situation | Materialization |
|-----------|-----------------|
| Development/testing | view |
| Final analytics tables | table |
| Large fact tables (append-only) | incremental |
| Reusable intermediate logic | ephemeral |

---

## Practical Examples

### Your Current Models

**my_first_dbt_model.sql:**
```sql
{{ config(materialized='table') }}

with source_data as (
    select 1 as id
    union all
    select null as id
)
select *
from source_data
```

- Materialization: `table`
- Creates: `saras-bigquery.dbt_training.my_first_dbt_model`

**my_second_dbt_model.sql:**
```sql
select *
from {{ ref('my_first_dbt_model') }}
where id = 1
```

- Materialization: `table` (inherited from dbt_project.yml)
- References: `my_first_dbt_model`
- Creates: `saras-bigquery.dbt_training.my_second_dbt_model`

**customers_from_seed.sql:**
```sql
{{ config(materialized='table') }}

select *
from {{ ref('example_customers') }}
```

- Materialization: `table`
- References: the seed `example_customers`
- Creates: `saras-bigquery.dbt_training.customers_from_seed`

---

## Summary

| Materialization | Creates | Best For |
|-----------------|---------|----------|
| `view` | SQL View | Light transforms, dev |
| `table` | Physical Table | Final tables, complex logic |
| `incremental` | Physical Table (append) | Large, append-only data |
| `ephemeral` | Nothing (CTE) | Reusable intermediate logic |

---

**Next:** [04_ref_and_source.md](04_ref_and_source.md)
