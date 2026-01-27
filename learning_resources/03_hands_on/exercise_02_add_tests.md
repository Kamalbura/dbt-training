# Exercise 2: Advanced Testing

## Objective

Learn to write custom tests and use dbt-utils package tests.

---

## Part A: Install dbt-utils

### Step 1: Create packages.yml

Create `packages.yml` in your project root:

```yaml
packages:
  - package: dbt-labs/dbt_utils
    version: 1.1.1
```

### Step 2: Install Packages

```powershell
dbt deps
```

This downloads the package into `dbt_packages/`.

### Step 3: Verify

```powershell
dir dbt_packages
```

You should see `dbt_utils/` folder.

---

## Part B: Add Advanced Tests

Update your `models/example/schema.yml` with advanced tests:

```yaml
version: 2

models:
  - name: customers_enhanced
    description: "Enhanced customer dimension"
    
    # Model-level tests
    tests:
      - dbt_utils.recency:
          datepart: day
          field: signup_date
          interval: 3650  # Fail if oldest signup is > 10 years ago
    
    columns:
      - name: customer_id
        description: "Primary key"
        tests:
          - unique
          - not_null
          - dbt_utils.not_constant  # Ensure not all same value
      
      - name: customer_email
        description: "Customer email"
        tests:
          - unique
          - not_null
          - dbt_utils.not_empty_string
      
      - name: days_since_signup
        description: "Days since signup"
        tests:
          - dbt_utils.accepted_range:
              min_value: 0
              max_value: 36500  # Max ~100 years
      
      - name: customer_tier
        tests:
          - accepted_values:
              values: ['founding_member', 'early_adopter', 'standard']
          - not_null
```

### Run the Tests

```powershell
dbt test --select customers_enhanced
```

---

## Part C: Write a Custom Singular Test

### Step 1: Create the Test File

Create `tests/assert_valid_email_format.sql`:

```sql
-- This test fails if any emails don't contain '@'
-- A proper email validation would use regex

SELECT
    customer_id,
    customer_email
FROM {{ ref('customers_enhanced') }}
WHERE customer_email NOT LIKE '%@%'
```

### Step 2: Run the Test

```powershell
dbt test --select assert_valid_email_format
```

If all emails contain '@', the test passes.

---

## Part D: Write a Custom Generic Test

Generic tests are reusable across models.

### Step 1: Create the Macro

Create `macros/test_is_positive.sql`:

```sql
{% test is_positive(model, column_name) %}

SELECT
    {{ column_name }}
FROM {{ model }}
WHERE {{ column_name }} < 0

{% endtest %}
```

### Step 2: Use in schema.yml

```yaml
columns:
  - name: days_since_signup
    tests:
      - is_positive  # Uses your custom test
```

### Step 3: Run

```powershell
dbt test --select customers_enhanced
```

---

## Part E: Test with WHERE Conditions

Sometimes you only want to test a subset of rows:

```yaml
columns:
  - name: customer_email
    tests:
      - not_null:
          where: "customer_tier = 'founding_member'"
          # Only founding members must have email
```

---

## Part F: Test Severity Levels

Make some tests warn instead of fail:

```yaml
columns:
  - name: days_since_signup
    tests:
      - dbt_utils.accepted_range:
          min_value: 0
          max_value: 3650
          severity: warn  # Warn if > 10 years, don't fail
          config:
            error_if: ">100"  # Fail if > 100 rows violate
            warn_if: ">10"    # Warn if > 10 rows violate
```

---

## Summary of Test Types

| Type | Location | Use Case |
|------|----------|----------|
| Built-in generic | schema.yml | unique, not_null, accepted_values, relationships |
| dbt-utils | schema.yml | Expression validation, ranges, recency |
| Singular | tests/*.sql | Custom one-off checks |
| Custom generic | macros/*.sql | Reusable custom patterns |

---

## Commands Learned

```powershell
# Install packages
dbt deps

# Run specific test
dbt test --select test_name

# Run all tests for model
dbt test --select model_name

# Run tests with full error output
dbt test --select model_name --store-failures
```

---

**Next:** [exercise_03_incremental.md](exercise_03_incremental.md)
