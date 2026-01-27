# dbt Best Practices

## Project Organization

### Recommended Folder Structure

```
models/
├── staging/           ← 1:1 with source tables
│   ├── stripe/
│   │   ├── _stripe__models.yml
│   │   ├── _stripe__sources.yml
│   │   ├── stg_stripe__payments.sql
│   │   └── stg_stripe__customers.sql
│   └── shopify/
│       ├── _shopify__models.yml
│       ├── _shopify__sources.yml
│       ├── stg_shopify__orders.sql
│       └── stg_shopify__products.sql
│
├── intermediate/      ← Business logic, joins
│   ├── finance/
│   │   └── int_payments_pivoted.sql
│   └── marketing/
│       └── int_customer_orders_joined.sql
│
└── marts/             ← Final tables for end users
    ├── core/          ← Shared across teams
    │   ├── dim_customers.sql
    │   └── fct_orders.sql
    └── finance/       ← Team-specific
        └── fct_monthly_revenue.sql
```

### Layer Descriptions

| Layer | Prefix | Purpose | Materialization |
|-------|--------|---------|-----------------|
| Staging | `stg_` | Light cleanup, renaming | view |
| Intermediate | `int_` | Complex joins, logic | ephemeral/view |
| Marts | `dim_`/`fct_` | Final analytics tables | table |

---

## Naming Conventions

### Models

```
stg_<source>__<table>.sql
int_<description>.sql
dim_<entity>.sql
fct_<event/process>.sql
```

**Examples:**
```
stg_stripe__payments.sql      ← staging from stripe payments
stg_shopify__orders.sql       ← staging from shopify orders
int_customer_orders_joined.sql
dim_customers.sql             ← dimension table
fct_orders.sql                ← fact table
```

### Columns

| Type | Convention | Example |
|------|------------|---------|
| Primary Key | `<entity>_id` | `customer_id`, `order_id` |
| Foreign Key | `<other_table>_id` | `product_id` |
| Timestamps | `<event>_at` | `created_at`, `updated_at` |
| Dates | `<event>_date` | `order_date`, `signup_date` |
| Booleans | `is_<state>` or `has_<thing>` | `is_active`, `has_subscription` |
| Amounts | `<thing>_amount` | `order_amount`, `refund_amount` |
| Counts | `<thing>_count` | `order_count`, `product_count` |

### YAML Files

```
_<source>__sources.yml    ← Source definitions
_<source>__models.yml     ← Model docs for that source
schema.yml                ← Alternative (per folder)
```

---

## Staging Layer Best Practices

### 1. One stg_ Model per Source Table

```sql
-- models/staging/stripe/stg_stripe__payments.sql

with source as (
    select * from {{ source('stripe', 'payments') }}
),

renamed as (
    select
        -- Primary key
        id as payment_id,
        
        -- Foreign keys
        customer_id,
        order_id,
        
        -- Timestamps
        created as created_at,
        
        -- Amounts (convert cents to dollars)
        amount / 100.0 as amount,
        
        -- Status
        lower(status) as status
    
    from source
)

select * from renamed
```

### 2. What to Do in Staging

✅ **Do:**
- Rename columns to standard naming
- Cast data types
- Convert units (cents to dollars)
- Select only needed columns

❌ **Don't:**
- Join tables
- Apply complex business logic
- Filter out records (usually)
- Aggregate

---

## Writing Clean SQL

### 1. Use CTEs, Not Subqueries

```sql
-- ❌ BAD: Nested subqueries
SELECT *
FROM (
    SELECT *
    FROM (
        SELECT *
        FROM raw_orders
        WHERE status = 'complete'
    ) completed
    WHERE amount > 0
) positive;

-- ✅ GOOD: CTEs
WITH completed_orders AS (
    SELECT *
    FROM raw_orders
    WHERE status = 'complete'
),

positive_orders AS (
    SELECT *
    FROM completed_orders
    WHERE amount > 0
)

SELECT * FROM positive_orders;
```

### 2. Name CTEs Meaningfully

```sql
-- ❌ BAD
with a as (...),
     b as (...),
     c as (...)

-- ✅ GOOD
with orders_with_customers as (...),
     orders_aggregated as (...),
     final as (...)
```

### 3. One Thing Per CTE

```sql
with

-- Get base data
orders as (
    select * from {{ ref('stg_orders') }}
),

-- Add customer info
orders_with_customers as (
    select
        o.*,
        c.customer_name,
        c.customer_segment
    from orders o
    left join {{ ref('dim_customers') }} c using (customer_id)
),

-- Aggregate
customer_order_summary as (
    select
        customer_id,
        customer_name,
        count(*) as order_count,
        sum(amount) as total_amount
    from orders_with_customers
    group by 1, 2
),

-- Final transformations
final as (
    select
        *,
        case
            when total_amount > 1000 then 'high_value'
            else 'standard'
        end as customer_tier
    from customer_order_summary
)

select * from final
```

### 4. Explicit Column Selection

```sql
-- ❌ BAD: Hidden dependencies
select * from customers

-- ✅ GOOD: Clear about what's selected
select
    customer_id,
    customer_name,
    email,
    created_at
from customers
```

---

## Testing Strategy

### Minimum Tests for Every Model

```yaml
models:
  - name: any_model
    columns:
      - name: primary_key_column
        tests:
          - unique
          - not_null
```

### Recommended Test Coverage

| Layer | Tests |
|-------|-------|
| Staging | PK unique/not_null |
| Intermediate | PK + business rules |
| Marts | PK + FK relationships + accepted values |

### Example Comprehensive Tests

```yaml
models:
  - name: fct_orders
    tests:
      - dbt_utils.unique_combination_of_columns:
          combination_of_columns:
            - order_id
            - line_item_id
    columns:
      - name: order_id
        tests:
          - not_null
      
      - name: customer_id
        tests:
          - not_null
          - relationships:
              to: ref('dim_customers')
              field: customer_id
      
      - name: order_status
        tests:
          - accepted_values:
              values: ['pending', 'complete', 'cancelled']
      
      - name: order_amount
        tests:
          - dbt_utils.expression_is_true:
              expression: ">= 0"
```

---

## Performance Best Practices

### 1. Choose the Right Materialization

```
Small, simple → view
Small, complex → table
Large, append-only → incremental
Reusable logic → ephemeral
```

### 2. Partition BigQuery Tables

```sql
{{
  config(
    materialized='table',
    partition_by={
      "field": "order_date",
      "data_type": "date",
      "granularity": "day"  -- or month, year
    }
  )
}}
```

### 3. Cluster Frequently Filtered Columns

```sql
{{
  config(
    materialized='table',
    partition_by={"field": "order_date", "data_type": "date"},
    cluster_by=['customer_id', 'product_id']
  )
}}
```

### 4. Limit Data in Development

```sql
-- Only process recent data in dev
{% if target.name == 'dev' %}
  where order_date >= date_sub(current_date(), interval 30 day)
{% endif %}
```

---

## Version Control Best Practices

### 1. .gitignore

```
# dbt artifacts
target/
dbt_packages/
logs/

# Environment
.env

# IDE
.vscode/
.idea/

# Credentials (NEVER commit these)
*.json
profiles.yml
```

### 2. Commit Often, Small Changes

```
❌ "Updated all models"
✅ "Add dim_customers model with tests"
✅ "Fix null handling in stg_orders"
```

### 3. Use Pull Requests

- One model or feature per PR
- Run `dbt run` and `dbt test` before merging
- Have someone review SQL logic

---

## Environment Management

### Separate Dev and Prod

```yaml
# profiles.yml
my_project:
  target: dev
  outputs:
    dev:
      type: bigquery
      dataset: dev_{{ env_var('USER') }}  # Each dev gets own schema
      ...
    
    prod:
      type: bigquery
      dataset: analytics
      ...
```

### Use Variables

```yaml
# dbt_project.yml
vars:
  start_date: '2020-01-01'
  enable_feature_x: false
```

```sql
-- In a model
select *
from orders
where order_date >= '{{ var("start_date") }}'
```

---

## Common Anti-Patterns

### 1. Too Many Joins in One Model

```sql
-- ❌ BAD: 7 joins in one place
select ...
from orders
join customers on ...
join products on ...
join categories on ...
join merchants on ...
join regions on ...
join currencies on ...
join discounts on ...

-- ✅ GOOD: Break into intermediate models
```

### 2. Business Logic in Multiple Places

```sql
-- ❌ BAD: Same logic duplicated
-- In model A:
case when amount > 1000 then 'high' else 'low' end

-- In model B:
case when amount > 1000 then 'high' else 'low' end

-- ✅ GOOD: Define once, reference
-- Create an intermediate model or macro
```

### 3. Hardcoded Values

```sql
-- ❌ BAD
where country_code in ('US', 'CA', 'MX')

-- ✅ GOOD: Use a seed or variable
where country_code in (select code from {{ ref('enabled_countries') }})
```

---

## Summary Checklist

Before every PR, verify:

- [ ] Model follows naming convention
- [ ] All columns explicitly listed (no SELECT *)
- [ ] Primary key tested for unique + not_null
- [ ] Model and columns have descriptions
- [ ] Uses ref() and source(), no hardcoded tables
- [ ] Appropriate materialization set
- [ ] Runs successfully locally
- [ ] Tests pass

---

**Next section:** [../03_hands_on/exercise_01_first_model.md](../03_hands_on/exercise_01_first_model.md)
