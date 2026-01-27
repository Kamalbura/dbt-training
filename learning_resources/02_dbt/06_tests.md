# Testing in dbt

## Why Test Data?

Bad data causes:
- Wrong business decisions
- Broken dashboards
- Angry stakeholders
- Lost trust

dbt tests catch problems **before** they reach production.

---

## Types of Tests

| Type | Where Defined | Use Case |
|------|---------------|----------|
| **Generic tests** | schema.yml | Common patterns (unique, not_null) |
| **Singular tests** | tests/*.sql | Custom, one-off assertions |

---

## Generic Tests (Built-in)

### The Four Core Tests

| Test | What It Checks | Fails When |
|------|----------------|------------|
| `unique` | No duplicate values | Same value appears twice |
| `not_null` | No NULL values | NULL found in column |
| `accepted_values` | Values in allowed list | Value not in list |
| `relationships` | Foreign key exists | ID not found in parent |

### Defining in schema.yml

```yaml
# models/example/schema.yml

version: 2

models:
  - name: customers_from_seed
    description: "Customer data from seed"
    columns:
      - name: id
        description: "Primary key"
        tests:
          - unique
          - not_null
      
      - name: email
        description: "Customer email"
        tests:
          - not_null
          - unique
```

### accepted_values Example

```yaml
columns:
  - name: status
    tests:
      - accepted_values:
          values: ['active', 'inactive', 'pending']
```

### relationships Example

```yaml
# In orders model
columns:
  - name: customer_id
    tests:
      - relationships:
          to: ref('customers')
          field: id
```

This checks: Every `customer_id` in orders exists in customers.id

---

## How Tests Work Internally

dbt converts your test definitions into SQL queries.

### unique test

**Your config:**
```yaml
columns:
  - name: id
    tests:
      - unique
```

**Generated SQL:**
```sql
SELECT id
FROM your_table
GROUP BY id
HAVING COUNT(*) > 1
```

**Logic:** If this returns ANY rows → FAIL (duplicates found)

### not_null test

**Generated SQL:**
```sql
SELECT id
FROM your_table
WHERE id IS NULL
```

**Logic:** If this returns ANY rows → FAIL (nulls found)

### accepted_values test

**Generated SQL:**
```sql
SELECT status
FROM your_table
WHERE status NOT IN ('active', 'inactive', 'pending')
   OR status IS NULL
```

### relationships test

**Generated SQL:**
```sql
SELECT customer_id
FROM orders
WHERE customer_id NOT IN (SELECT id FROM customers)
  AND customer_id IS NOT NULL
```

---

## Singular Tests (Custom SQL)

For complex assertions that don't fit generic tests.

### Creating a Singular Test

```sql
-- tests/assert_positive_amounts.sql

-- This test FAILS if it returns any rows
SELECT
  order_id,
  amount
FROM {{ ref('orders') }}
WHERE amount < 0
```

**Rule:** If the query returns 0 rows → PASS. Any rows → FAIL.

### More Examples

**Test: ensure no future dates**
```sql
-- tests/no_future_dates.sql
SELECT *
FROM {{ ref('orders') }}
WHERE order_date > CURRENT_DATE()
```

**Test: ensure referential integrity**
```sql
-- tests/orphan_orders.sql
SELECT o.*
FROM {{ ref('orders') }} o
LEFT JOIN {{ ref('customers') }} c ON o.customer_id = c.id
WHERE c.id IS NULL
```

---

## Running Tests

```powershell
# Run all tests
dbt test

# Run tests for specific model
dbt test --select customers_from_seed

# Run tests for models in a folder
dbt test --select staging.*

# Run tests AND models together
dbt build --select customers_from_seed

# Show full output on failure
dbt test --select my_model --store-failures
```

---

## Test Results

### Passing Output

```
05:42:04  1 of 3 START test not_null_example_customers_email ..... [RUN]
05:42:08  1 of 3 PASS not_null_example_customers_email ........... [PASS in 4.32s]
```

### Failing Output

```
05:42:04  1 of 3 START test unique_customers_id .................. [RUN]
05:42:08  1 of 3 FAIL 2 unique_customers_id ...................... [FAIL 2 in 4.32s]
```

The `FAIL 2` means 2 rows were returned (2 duplicate IDs found).

---

## Test Severity

Control what happens when a test fails:

```yaml
columns:
  - name: id
    tests:
      - unique
      - not_null:
          severity: warn  # Warn instead of fail
```

| Severity | Behavior |
|----------|----------|
| `error` (default) | Test failure stops the build |
| `warn` | Test logs a warning but continues |

---

## Where to Return Failures

Store test failures for debugging:

```yaml
# dbt_project.yml
tests:
  +store_failures: true
  +schema: test_failures
```

Failed rows get saved to `test_failures` schema for investigation.

---

## Your Current Tests

**seeds/schema.yml:**
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

**What ran:**
1. `unique_example_customers_id` → PASS
2. `not_null_example_customers_id` → PASS
3. `not_null_example_customers_email` → PASS

---

## Test Configuration Options

```yaml
models:
  - name: orders
    columns:
      - name: amount
        tests:
          - not_null:
              severity: warn
              where: "order_status != 'cancelled'"
          - dbt_utils.accepted_range:
              min_value: 0
              max_value: 10000
```

### Common Options

| Option | Purpose |
|--------|---------|
| `severity` | error or warn |
| `where` | Filter rows before testing |
| `config` | Additional test settings |

---

## Package Tests (dbt-utils)

Install packages for more tests:

**packages.yml:**
```yaml
packages:
  - package: dbt-labs/dbt_utils
    version: 1.1.1
```

**Install:**
```powershell
dbt deps
```

**Use:**
```yaml
columns:
  - name: email
    tests:
      - dbt_utils.not_empty_string
      - dbt_utils.not_constant

  - name: amount
    tests:
      - dbt_utils.accepted_range:
          min_value: 0

  - name: created_at
    tests:
      - dbt_utils.recency:
          datepart: day
          field: created_at
          interval: 1
```

---

## Testing Best Practices

### 1. Test Primary Keys

Every model should test:
```yaml
- name: id
  tests:
    - unique
    - not_null
```

### 2. Test Foreign Keys

```yaml
- name: customer_id
  tests:
    - relationships:
        to: ref('dim_customers')
        field: customer_id
```

### 3. Test Business Rules

```yaml
- name: order_total
  tests:
    - dbt_utils.expression_is_true:
        expression: ">= 0"
```

### 4. Start Simple, Add Over Time

Begin with `unique` and `not_null`, add more as you find issues.

---

## Summary

| Test Type | Location | Use For |
|-----------|----------|---------|
| Generic (unique, not_null, etc.) | schema.yml | Common patterns |
| Singular | tests/*.sql | Custom assertions |
| Package tests | schema.yml | Advanced patterns |

**Commands:**
- `dbt test` — Run all tests
- `dbt test --select model_name` — Test specific model
- `dbt build` — Run and test together

---

**Next:** [07_documentation.md](07_documentation.md)
