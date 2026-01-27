# Exercise 3: Incremental Models

## Objective

Learn how incremental models work and when to use them.

---

## Why Incremental?

| Full Refresh | Incremental |
|--------------|-------------|
| Rebuilds entire table | Only adds new/changed rows |
| Simple logic | More complex logic |
| Slow for large tables | Fast for large tables |
| Expensive (scans all data) | Cheap (scans only new data) |

**Use incremental for:** Large fact tables, event logs, time-series data

---

## How It Works

```
First run (full load):
┌─────────────────────────────────────┐
│ Source: All rows                    │
│ Result: Table created with all data │
└─────────────────────────────────────┘

Subsequent runs:
┌─────────────────────────────────────┐
│ Source: Only new rows (filtered)    │
│ Result: New rows inserted/merged    │
└─────────────────────────────────────┘
```

---

## Step 1: Create Sample Event Seed

Create `seeds/events.csv`:

```csv
event_id,customer_id,event_type,event_date,amount
1,1,purchase,2023-01-05,100
2,1,view,2023-01-06,0
3,2,purchase,2023-01-07,50
4,2,view,2023-01-08,0
5,3,purchase,2023-01-09,200
```

Load it:
```powershell
dbt seed --select events
```

---

## Step 2: Create Incremental Model

Create `models/example/fct_events.sql`:

```sql
{{
  config(
    materialized='incremental',
    unique_key='event_id',
    on_schema_change='append_new_columns'
  )
}}

{#
  Fact table for customer events.
  
  Incremental strategy:
  - Uses event_date to identify new records
  - unique_key prevents duplicates
#}

with source_events as (
    select *
    from {{ ref('events') }}
),

transformed as (
    select
        event_id,
        customer_id,
        event_type,
        event_date,
        amount,
        
        -- Add processing metadata
        current_timestamp() as loaded_at
        
    from source_events
    
    -- Only process new events on incremental runs
    {% if is_incremental() %}
    where event_date > (select max(event_date) from {{ this }})
    {% endif %}
)

select * from transformed
```

---

## Step 3: Understanding the Magic

### The `is_incremental()` Macro

```sql
{% if is_incremental() %}
    where event_date > (select max(event_date) from {{ this }})
{% endif %}
```

- **First run:** `is_incremental()` returns FALSE
  - WHERE clause is skipped
  - All rows are processed
  
- **Subsequent runs:** `is_incremental()` returns TRUE
  - WHERE clause filters to new rows only
  - `{{ this }}` refers to the existing table

### The `unique_key` Config

```sql
{{ config(unique_key='event_id') }}
```

This tells dbt how to handle duplicates:
- On BigQuery: Uses MERGE statement
- If a row with same event_id exists, it's updated
- If new, it's inserted

---

## Step 4: Run It

### First Run (Full Load)

```powershell
dbt run --select fct_events
```

Check the output:
```
[CREATE TABLE (5.0 rows, ...)]
```

All 5 rows loaded.

### Add New Events

Update `seeds/events.csv`:

```csv
event_id,customer_id,event_type,event_date,amount
1,1,purchase,2023-01-05,100
2,1,view,2023-01-06,0
3,2,purchase,2023-01-07,50
4,2,view,2023-01-08,0
5,3,purchase,2023-01-09,200
6,1,purchase,2023-01-10,75
7,3,view,2023-01-11,0
```

Reload seed and run model:

```powershell
dbt seed --select events
dbt run --select fct_events
```

Check output:
```
[MERGE (2.0 rows, ...)]
```

Only 2 new rows processed!

### Force Full Refresh

To rebuild from scratch:

```powershell
dbt run --select fct_events --full-refresh
```

---

## Step 5: Add Documentation

Add to `models/example/schema.yml`:

```yaml
  - name: fct_events
    description: >
      Fact table containing all customer events.
      
      **Materialization:** Incremental (daily append)
      **Grain:** One row per event
      **Unique Key:** event_id
      **Incremental Strategy:** Filter by event_date > max(existing)
    
    columns:
      - name: event_id
        description: "Primary key"
        tests:
          - unique
          - not_null
      
      - name: customer_id
        description: "FK to customers"
        tests:
          - not_null
          - relationships:
              to: ref('example_customers')
              field: id
      
      - name: event_type
        description: "Type of event"
        tests:
          - accepted_values:
              values: ['purchase', 'view', 'signup']
```

---

## Incremental Strategies

### 1. Append (Default)

Just insert new rows. Fastest but no updates.

```sql
{{ config(materialized='incremental') }}

select * from source
{% if is_incremental() %}
where created_at > (select max(created_at) from {{ this }})
{% endif %}
```

### 2. Merge (with unique_key)

Insert new, update existing. Uses BigQuery MERGE.

```sql
{{
  config(
    materialized='incremental',
    unique_key='id'
  )
}}
```

### 3. Insert Overwrite (Partition)

Replace entire partitions. Good for late-arriving data.

```sql
{{
  config(
    materialized='incremental',
    incremental_strategy='insert_overwrite',
    partition_by={'field': 'event_date', 'data_type': 'date'}
  )
}}
```

---

## Common Patterns

### Filter by Timestamp

```sql
{% if is_incremental() %}
where updated_at > (select max(updated_at) from {{ this }})
{% endif %}
```

### Filter by Date Partition

```sql
{% if is_incremental() %}
where date(created_at) >= (select max(date(created_at)) from {{ this }})
{% endif %}
```

### Handle Late-Arriving Data

Look back a few days:

```sql
{% if is_incremental() %}
where event_date >= date_sub(
    (select max(event_date) from {{ this }}),
    interval 3 day
)
{% endif %}
```

---

## Troubleshooting

### Problem: Duplicates

**Cause:** unique_key not set or wrong column

**Fix:** 
```sql
{{ config(unique_key='your_pk_column') }}
```

### Problem: Missing Data

**Cause:** Filter too aggressive

**Fix:** Look back further or use insert_overwrite

### Problem: Slow Incrementals

**Cause:** WHERE clause not using partition column

**Fix:** Filter on partition column first

---

## Summary

| Config | Purpose |
|--------|---------|
| `materialized='incremental'` | Enable incremental |
| `unique_key` | Column(s) for merge logic |
| `incremental_strategy` | append, merge, insert_overwrite |
| `is_incremental()` | Jinja to detect incremental run |
| `{{ this }}` | Reference to existing table |
| `--full-refresh` | Force complete rebuild |

---

## Commands

```powershell
# Normal incremental run
dbt run --select fct_events

# Force full rebuild
dbt run --select fct_events --full-refresh

# Run and test
dbt build --select fct_events
```

---

**Back to:** [../00_START_HERE.md](../00_START_HERE.md)
