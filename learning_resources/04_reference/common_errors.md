# Common dbt Errors and Solutions

## Quick Troubleshooting Guide

When you see an error, find it here for the fix.

---

## Connection Errors

### Error: Could not find profile named 'X'

**Full message:**
```
Could not find profile named 'default'
```

**Cause:** dbt can't find profiles.yml or the profile name doesn't match.

**Fix:**
1. Check profiles.yml exists:
   ```powershell
   cat $env:USERPROFILE\.dbt\profiles.yml
   ```
2. Ensure profile name in profiles.yml matches dbt_project.yml:
   ```yaml
   # dbt_project.yml
   profile: 'default'  # Must match profiles.yml
   
   # profiles.yml
   default:            # This name must match
     target: dev
     ...
   ```

---

### Error: Authentication failed

**Full message:**
```
google.auth.exceptions.DefaultCredentialsError
```

**Cause:** Service account key is missing or invalid.

**Fix:**
1. Check keyfile path in profiles.yml is correct
2. Verify the JSON file exists:
   ```powershell
   cat $env:USERPROFILE\.dbt\service-account.json
   ```
3. Ensure service account has required permissions in GCP

---

### Error: Dataset not found

**Full message:**
```
Not found: Dataset saras-bigquery:my_dataset
```

**Cause:** The dataset doesn't exist in BigQuery.

**Fix:**
1. Create the dataset in BigQuery Console
2. Or use bq CLI:
   ```powershell
   bq mk --dataset saras-bigquery:my_dataset
   ```

---

## Compilation Errors

### Error: Compilation Error - ref() not found

**Full message:**
```
Compilation Error: Model 'model_name' depends on a node named 'other_model' which was not found
```

**Cause:** The referenced model doesn't exist or is misspelled.

**Fix:**
1. Check spelling: `{{ ref('other_model') }}`
2. Verify the file exists: `models/*/other_model.sql`
3. Check it's not disabled in config

---

### Error: Compilation Error - source not found

**Full message:**
```
Compilation Error: source 'raw.customers' was not found
```

**Cause:** Source isn't defined in a sources.yml file.

**Fix:**
Add source definition:
```yaml
# models/staging/sources.yml
version: 2
sources:
  - name: raw
    tables:
      - name: customers
```

---

### Error: Invalid Jinja Syntax

**Full message:**
```
Compilation Error: expected token 'end of print statement', got ','
```

**Cause:** Jinja syntax error in your SQL file.

**Fix:**
Check for common issues:
```sql
-- ❌ Wrong: extra comma
{{ config(materialized='table',) }}

-- ✅ Right
{{ config(materialized='table') }}

-- ❌ Wrong: missing quotes
{{ ref(my_model) }}

-- ✅ Right
{{ ref('my_model') }}
```

---

### Error: Undefined Variable

**Full message:**
```
Compilation Error: 'var_name' is undefined
```

**Cause:** Variable not defined in dbt_project.yml.

**Fix:**
```yaml
# dbt_project.yml
vars:
  var_name: 'value'
```

Or provide default:
```sql
{{ var('var_name', 'default_value') }}
```

---

## Runtime Errors

### Error: Duplicate column names

**Full message:**
```
Duplicate column names in the result are not supported
```

**Cause:** SELECT has same column name twice.

**Fix:**
```sql
-- ❌ Wrong
SELECT c.id, o.id FROM customers c JOIN orders o ON ...

-- ✅ Right
SELECT c.id as customer_id, o.id as order_id FROM ...
```

---

### Error: Query exceeded maximum bytes billed

**Full message:**
```
Query exceeded limit for bytes billed: 1000000000
```

**Cause:** Query would scan too much data.

**Fix:**
1. Add more WHERE filters
2. Select specific columns instead of *
3. Filter on partitioned column
4. Increase limit in profiles.yml:
   ```yaml
   maximum_bytes_billed: 10000000000  # 10GB
   ```

---

### Error: Access Denied

**Full message:**
```
Access Denied: Dataset project:dataset
```

**Cause:** Service account lacks permissions.

**Fix:**
Grant roles in GCP Console:
- `BigQuery Data Editor` (to create tables)
- `BigQuery Job User` (to run queries)

---

## Test Failures

### Error: Test failed

**Full message:**
```
Failure in test unique_customers_id (models/schema.yml)
Got 2 results, configured to fail if != 0
```

**Cause:** Data doesn't pass the test (duplicates found).

**Fix:**
1. Investigate the data:
   ```powershell
   dbt test --select unique_customers_id --store-failures
   ```
2. Query the failures table in BigQuery
3. Fix source data or update model logic

---

### Error: Relationship test failed

**Full message:**
```
Failure in test relationships_orders_customer_id
```

**Cause:** Foreign key has values not in parent table.

**Fix:**
1. Check for orphaned records
2. Add WHERE clause to exclude them
3. Or fix the source data

---

## Incremental Model Errors

### Error: Incremental model requires unique_key

**Full message:**
```
Runtime Error: merge_update_columns requires unique_key
```

**Cause:** Using merge strategy without unique_key.

**Fix:**
```sql
{{ config(
    materialized='incremental',
    unique_key='id'  -- Add this
) }}
```

---

### Error: is_incremental() always false

**Cause:** Table doesn't exist yet (first run) or was dropped.

**Fix:**
This is expected on first run. Run twice to verify.

---

## Package Errors

### Error: Package not found

**Full message:**
```
Package dbt-labs/dbt_utils was not found
```

**Cause:** Packages not installed.

**Fix:**
```powershell
dbt deps
```

---

### Error: Package version conflict

**Full message:**
```
Could not find a version that satisfies the requirement
```

**Cause:** Package versions are incompatible.

**Fix:**
Update packages.yml to compatible versions:
```yaml
packages:
  - package: dbt-labs/dbt_utils
    version: [">=1.0.0", "<2.0.0"]
```

---

## Quick Checks

When something goes wrong, try these in order:

```powershell
# 1. Check dbt and adapter versions
dbt --version

# 2. Check connection
dbt debug

# 3. Clean and retry
dbt clean
dbt deps
dbt run --select my_model

# 4. Check compiled SQL
dbt compile --select my_model
cat target/compiled/...

# 5. Full refresh if incremental issues
dbt run --select my_model --full-refresh
```

---

## Getting Help

1. **Read the error carefully** - dbt errors are usually descriptive
2. **Check compiled SQL** - `target/compiled/...`
3. **Check logs** - `logs/dbt.log`
4. **dbt Discourse** - https://discourse.getdbt.com
5. **dbt Slack** - https://community.getdbt.com

---

**Back to:** [../00_START_HERE.md](../00_START_HERE.md)
