# ref() and source() Functions

These are the two most important functions in dbt. They connect your models together.

---

## ref() — Reference Other Models

### What It Does

`ref()` creates a dependency between models and returns the correct table name.

```sql
-- models/downstream_model.sql
select * from {{ ref('upstream_model') }}
```

### Why Use ref() Instead of Hardcoding?

```sql
-- ❌ BAD: Hardcoded table name
select * from `saras-bigquery.dbt_training.example_customers`

-- ✅ GOOD: Using ref()
select * from {{ ref('example_customers') }}
```

**Benefits of ref():**

1. **Automatic dependency graph**
   - dbt knows to build `example_customers` first
   - Order is handled automatically

2. **Environment flexibility**
   - In dev: `saras-bigquery.dbt_dev.example_customers`
   - In prod: `saras-bigquery.dbt_prod.example_customers`
   - Same code, different environments

3. **Renaming safety**
   - If you change `dbt_project.yml` settings, ref() adapts
   - No need to update hardcoded names

### How ref() Gets Compiled

**Your code:**
```sql
select * from {{ ref('example_customers') }}
```

**After compilation:**
```sql
select * from `saras-bigquery.dbt_training.example_customers`
```

### ref() for Seeds

Seeds are referenced the same way:

```sql
-- Seeds are just like models for ref()
select * from {{ ref('example_customers') }}  -- This is a seed!
```

### ref() Across Projects

If you have multiple dbt projects, use two arguments:

```sql
-- Reference a model from another project
select * from {{ ref('other_project', 'their_model') }}
```

---

## source() — Reference Raw Data

### What It Does

`source()` references raw tables that are NOT managed by dbt.

```sql
select * from {{ source('raw_data', 'customers') }}
```

### When to Use source() vs ref()

| Use | For |
|-----|-----|
| `ref()` | Tables/views created BY dbt (models, seeds) |
| `source()` | Tables that exist OUTSIDE dbt (raw data, external) |

### Defining Sources

Sources are defined in a YAML file:

```yaml
# models/staging/sources.yml

version: 2

sources:
  - name: raw_data                    # Source name (used in source())
    database: saras-bigquery          # Optional: specify database/project
    schema: raw_schema                # Dataset containing raw tables
    tables:
      - name: customers               # Table name
        description: "Raw customer data from CRM"
      - name: orders
        description: "Raw order data from e-commerce platform"
```

### Using Sources in Models

```sql
-- models/staging/stg_customers.sql

select
  id as customer_id,
  email,
  created_at
from {{ source('raw_data', 'customers') }}
```

**Compiled:**
```sql
select
  id as customer_id,
  email,
  created_at
from `saras-bigquery.raw_schema.customers`
```

### Source Freshness

dbt can check if source data is up to date:

```yaml
sources:
  - name: raw_data
    tables:
      - name: orders
        loaded_at_field: _loaded_at    # Column that has load timestamp
        freshness:
          warn_after: {count: 12, period: hour}
          error_after: {count: 24, period: hour}
```

**Check freshness:**
```powershell
dbt source freshness
```

---

## The Dependency Graph (DAG)

dbt builds a **Directed Acyclic Graph** from your ref() and source() calls.

### Example

```
sources.yml:
  source('raw', 'customers')
  source('raw', 'orders')

stg_customers.sql:
  select * from {{ source('raw', 'customers') }}

stg_orders.sql:
  select * from {{ source('raw', 'orders') }}

int_customer_orders.sql:
  select ...
  from {{ ref('stg_customers') }} c
  join {{ ref('stg_orders') }} o on c.id = o.customer_id

dim_customers.sql:
  select * from {{ ref('int_customer_orders') }}
```

**The DAG:**
```
    [raw.customers]     [raw.orders]
          │                   │
          ▼                   ▼
    stg_customers       stg_orders
          │                   │
          └─────────┬─────────┘
                    │
                    ▼
           int_customer_orders
                    │
                    ▼
             dim_customers
```

### Why the DAG Matters

1. **Correct build order**
   - dbt runs `stg_customers` before `int_customer_orders`
   - No manual ordering needed

2. **Selective runs**
   ```powershell
   # Run stg_customers and everything downstream
   dbt run --select stg_customers+
   
   # Run dim_customers and everything upstream
   dbt run --select +dim_customers
   ```

3. **Impact analysis**
   - Change stg_customers → dim_customers will be affected
   - dbt docs visualize this

---

## Your Current Dependencies

```
                [seed: example_customers]
                          │
            ┌─────────────┼─────────────┐
            ▼             ▼             ▼
    customers_from_seed   │    my_first_dbt_model
                          │             │
                          │             ▼
                          │    my_second_dbt_model
                          │
            (no dependency to first/second models)
```

**customers_from_seed.sql:**
```sql
select * from {{ ref('example_customers') }}
-- Depends on: example_customers seed
```

**my_second_dbt_model.sql:**
```sql
select * from {{ ref('my_first_dbt_model') }}
where id = 1
-- Depends on: my_first_dbt_model
```

---

## Viewing the DAG

Generate and view the documentation:

```powershell
dbt docs generate
dbt docs serve
```

This opens a web browser with:
- Interactive DAG visualization
- Model documentation
- Column descriptions
- Test results

---

## Common Patterns

### Staging Layer (source → stg_)

```sql
-- models/staging/stg_customers.sql
select
  id as customer_id,
  email,
  created_at as customer_created_at
from {{ source('raw', 'customers') }}
where email is not null
```

### Intermediate Layer (stg_ → int_)

```sql
-- models/intermediate/int_customer_orders.sql
select
  c.customer_id,
  c.email,
  count(o.order_id) as order_count,
  sum(o.amount) as total_spent
from {{ ref('stg_customers') }} c
left join {{ ref('stg_orders') }} o on c.customer_id = o.customer_id
group by 1, 2
```

### Marts Layer (int_/stg_ → dim_/fct_)

```sql
-- models/marts/core/dim_customers.sql
select
  customer_id,
  email,
  order_count,
  total_spent,
  case
    when total_spent > 1000 then 'high_value'
    when total_spent > 100 then 'medium_value'
    else 'low_value'
  end as customer_segment
from {{ ref('int_customer_orders') }}
```

---

## Summary

| Function | Purpose | Example |
|----------|---------|---------|
| `ref()` | Reference dbt-managed models/seeds | `{{ ref('stg_customers') }}` |
| `source()` | Reference raw/external tables | `{{ source('raw', 'customers') }}` |

**Key rules:**
- Use `ref()` for anything dbt creates
- Use `source()` for anything dbt doesn't create
- Never hardcode table names
- Let dbt build the dependency graph

---

**Next:** [05_seeds.md](05_seeds.md)
