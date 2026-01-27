# Documentation in dbt

## Why Document?

Six months from now:
- What does `fct_orders_v2_final` mean?
- What's the difference between `amount` and `total_amount`?
- Why is there a `WHERE status != 'test'`?

Documentation prevents confusion and saves time.

---

## Documentation Methods

| Method | Where | Best For |
|--------|-------|----------|
| **YAML descriptions** | schema.yml | Column/model descriptions |
| **Doc blocks** | *.md files | Long-form explanations |
| **In-line comments** | *.sql files | Implementation details |

---

## YAML Descriptions

### Model Description

```yaml
# models/example/schema.yml

version: 2

models:
  - name: customers_from_seed
    description: >
      Customer dimension table built from seed data.
      Contains one row per customer with their profile information.
      
      **Owner:** Data Team
      **Refresh:** Daily
    
    columns:
      - name: id
        description: "Unique identifier for each customer (primary key)"
      
      - name: name
        description: "Customer's full name as provided during signup"
      
      - name: email
        description: "Customer's email address (validated format)"
      
      - name: signup_date
        description: "Date when the customer created their account"
```

### Tips for Good Descriptions

```yaml
# ❌ BAD: Obvious, unhelpful
- name: email
  description: "The email"

# ✅ GOOD: Context and business meaning
- name: email
  description: >
    Customer's primary email address. Used for marketing communications
    and account recovery. Validated to ensure proper format.
    PII - handle according to data privacy policy.
```

---

## Doc Blocks (Long-form Documentation)

For detailed explanations, use Markdown files.

### Step 1: Create a Doc Block

```markdown
<!-- docs/customer_segments.md -->

{% docs customer_segment %}

## Customer Segmentation

Customers are segmented based on their total lifetime value:

| Segment | Criteria | Treatment |
|---------|----------|-----------|
| High Value | Total spend > $1000 | Priority support |
| Medium Value | Total spend $100-$1000 | Standard support |
| Low Value | Total spend < $100 | Self-service |

### Calculation

The segment is calculated daily based on the sum of all completed orders.
Pending and cancelled orders are excluded.

### Business Owner

Contact: analytics@company.com

{% enddocs %}
```

### Step 2: Reference in schema.yml

```yaml
models:
  - name: dim_customers
    columns:
      - name: customer_segment
        description: '{{ doc("customer_segment") }}'
```

---

## In-line SQL Comments

```sql
-- models/marts/fct_orders.sql

{{
  config(
    materialized='incremental',
    unique_key='order_id'
  )
}}

/*
  Fact table for completed orders.
  
  Grain: One row per order
  
  Refresh: Incremental, based on order_date
  
  Notes:
  - Excludes test orders (order_type != 'test')
  - Amounts are in USD
  - Joined with dim_customers for customer details
*/

with orders as (
    select *
    from {{ ref('stg_orders') }}
    -- Exclude test orders created by QA team
    where order_type != 'test'
),

customers as (
    select *
    from {{ ref('dim_customers') }}
)

select
    o.order_id,
    o.order_date,
    o.customer_id,
    c.customer_name,
    o.amount,  -- Amount in USD, converted from source currency
    o.status
from orders o
left join customers c on o.customer_id = c.customer_id

{% if is_incremental() %}
    -- Only process new orders since last run
    where o.order_date > (select max(order_date) from {{ this }})
{% endif %}
```

---

## Generating Documentation

### Step 1: Generate

```powershell
dbt docs generate
```

This creates:
- `target/manifest.json` — Project metadata
- `target/catalog.json` — Column info from warehouse
- `target/index.html` — Documentation website

### Step 2: Serve Locally

```powershell
dbt docs serve
```

Opens a browser with:
- Interactive DAG
- Model documentation
- Column descriptions
- Test results
- Source information

### Step 3: Explore the DAG

![DAG Example](https://docs.getdbt.com/img/docs/running-a-dbt-project/dbt-dag.png)

Click on any model to see:
- Description
- Column list
- Dependencies
- Code

---

## Documentation Best Practices

### 1. Document the Business, Not the Code

```yaml
# ❌ BAD: Restates the SQL
- name: total_amount
  description: "sum of amount column"

# ✅ GOOD: Explains business meaning
- name: total_amount
  description: >
    Total revenue from this order in USD, including tax and shipping.
    Excludes refunded amounts.
```

### 2. Include Ownership

```yaml
models:
  - name: fct_revenue
    description: >
      **Owner:** Finance Analytics Team
      **Slack:** #finance-data
      **Refresh:** Daily at 6am UTC
```

### 3. Document Known Issues

```yaml
models:
  - name: stg_legacy_orders
    description: >
      ⚠️ **Known Issues:**
      - Orders before 2020-01-01 may have incorrect timestamps
      - customer_id is NULL for ~2% of records (guest checkouts)
```

### 4. Add Data Sensitivity Labels

```yaml
columns:
  - name: email
    description: |
      Customer email address.
      **PII Level:** High
      **Retention:** 7 years
      **Encryption:** Required
```

---

## Persist Docs to Warehouse

Make descriptions visible in BigQuery:

```yaml
# dbt_project.yml

models:
  my_project:
    +persist_docs:
      relation: true   # Table/view description
      columns: true    # Column descriptions
```

Now when you query in BigQuery Console, you'll see descriptions!

---

## Documentation Structure

Organize docs for large projects:

```
models/
├── staging/
│   ├── stg_customers.sql
│   └── schema.yml          ← Docs for staging models
├── intermediate/
│   ├── int_customer_orders.sql
│   └── schema.yml
├── marts/
│   ├── core/
│   │   ├── dim_customers.sql
│   │   └── schema.yml      ← Core marts docs
│   └── finance/
│       ├── fct_revenue.sql
│       └── schema.yml      ← Finance docs
docs/
├── overview.md             ← Project overview
├── customer_dimensions.md  ← Detailed doc blocks
└── metrics_definitions.md
```

---

## Your Documentation

### What You Have

**models/example/schema.yml:**
```yaml
version: 2

models:
    - name: my_first_dbt_model
      description: "A starter dbt model"
      columns:
          - name: id
            description: "The primary key for this table"
            tests:
                - unique
                - not_null
```

**seeds/schema.yml:**
```yaml
version: 2

seeds:
  - name: example_customers
    description: "Sample customers seed for practice"
    columns:
      - name: id
        tests:
          - unique
          - not_null
```

### Try It Now

```powershell
dbt docs generate
dbt docs serve
```

---

## Summary

| Component | Location | Purpose |
|-----------|----------|---------|
| Model descriptions | schema.yml | What the model does |
| Column descriptions | schema.yml | What each column means |
| Doc blocks | *.md files | Detailed explanations |
| SQL comments | *.sql files | Implementation notes |

**Commands:**
- `dbt docs generate` — Create documentation
- `dbt docs serve` — View in browser

---

**Next:** [08_dbt_best_practices.md](08_dbt_best_practices.md)
