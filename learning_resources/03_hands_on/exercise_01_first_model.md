# Exercise 1: Create Your First Model from Scratch

## Objective

Create a new model that transforms the seed data, following best practices.

---

## The Task

Create a model called `customers_enhanced` that:
1. Selects from `example_customers`
2. Adds a calculated column for "days since signup"
3. Adds a customer tier based on their ID
4. Has proper documentation and tests

---

## Step 1: Create the SQL File

Create the file `models/example/customers_enhanced.sql`:

```sql
{{ config(materialized='table') }}

{#
  This model enhances the raw customer data with calculated fields.
  
  Grain: One row per customer
  Source: example_customers seed
#}

with customers as (
    -- Get base customer data from seed
    select *
    from {{ ref('example_customers') }}
),

enhanced as (
    select
        -- Primary key
        id as customer_id,
        
        -- Attributes
        name as customer_name,
        email as customer_email,
        signup_date,
        
        -- Calculated: days since signup
        date_diff(current_date(), signup_date, day) as days_since_signup,
        
        -- Calculated: customer tier based on ID
        -- (In real world, this would be based on spend/behavior)
        case
            when id = 1 then 'founding_member'
            when id <= 2 then 'early_adopter'
            else 'standard'
        end as customer_tier,
        
        -- Metadata
        current_timestamp() as model_created_at
        
    from customers
)

select * from enhanced
```

---

## Step 2: Add Documentation and Tests

Update `models/example/schema.yml` to include the new model:

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

  - name: my_second_dbt_model
    description: "A starter dbt model"
    columns:
      - name: id
        description: "The primary key for this table"
        tests:
          - unique
          - not_null
  
  # ADD THIS SECTION
  - name: customers_enhanced
    description: >
      Enhanced customer dimension with calculated fields.
      One row per customer.
    columns:
      - name: customer_id
        description: "Unique customer identifier (primary key)"
        tests:
          - unique
          - not_null
      
      - name: customer_name
        description: "Customer's full name"
        tests:
          - not_null
      
      - name: customer_email
        description: "Customer's email address"
        tests:
          - unique
          - not_null
      
      - name: signup_date
        description: "Date the customer signed up"
        tests:
          - not_null
      
      - name: days_since_signup
        description: "Number of days between signup and today"
      
      - name: customer_tier
        description: "Customer classification tier"
        tests:
          - accepted_values:
              values: ['founding_member', 'early_adopter', 'standard']
```

---

## Step 3: Run and Test

```powershell
# Build the model
dbt run --select customers_enhanced

# Test the model
dbt test --select customers_enhanced

# Or do both at once
dbt build --select customers_enhanced
```

---

## Step 4: Verify in BigQuery

```powershell
# Query the new table
bq query --nouse_legacy_sql "
SELECT * FROM \`saras-bigquery.dbt_training.customers_enhanced\`
"
```

Expected output:
```
+-------------+---------------+---------------------+-------------+-------------------+------------------+
| customer_id | customer_name | customer_email      | signup_date | days_since_signup | customer_tier    |
+-------------+---------------+---------------------+-------------+-------------------+------------------+
| 1           | Alice         | alice@example.com   | 2023-01-05  | 1118              | founding_member  |
| 2           | Bob           | bob@example.com     | 2023-02-10  | 1082              | early_adopter    |
| 3           | Charlie       | charlie@example.com | 2023-03-15  | 1049              | standard         |
+-------------+---------------+---------------------+-------------+-------------------+------------------+
```

---

## Step 5: View the DAG

```powershell
dbt docs generate
dbt docs serve
```

You should see:
```
example_customers (seed)
        │
        ├──────► customers_from_seed
        │
        └──────► customers_enhanced (new!)
```

---

## What You Learned

1. **CTE structure:** base data → transformations → final select
2. **ref() function:** Reference seeds/models by name
3. **config block:** Set materialization
4. **Comments:** Document your intent
5. **schema.yml:** Add descriptions and tests
6. **dbt build:** Run and test in one command

---

## Bonus Challenge

Add another column to classify customers by email domain:

```sql
-- Add this in the enhanced CTE
case
    when email like '%@gmail.com' then 'personal'
    when email like '%@example.com' then 'test'
    else 'business'
end as email_type
```

---

**Next:** [exercise_02_add_tests.md](exercise_02_add_tests.md)
