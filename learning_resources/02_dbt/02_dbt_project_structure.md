# dbt Project Structure

## Your Project Layout

```
dbt-training/                      ← Project root
├── dbt_project.yml                ← Main config file
├── profiles.yml                   ← Connection settings (usually in ~/.dbt/)
├── models/                        ← Your SQL transformations
│   └── example/
│       ├── my_first_dbt_model.sql
│       ├── my_second_dbt_model.sql
│       ├── customers_from_seed.sql
│       └── schema.yml
├── seeds/                         ← CSV files to load
│   ├── example_customers.csv
│   └── schema.yml
├── tests/                         ← Custom SQL tests
├── macros/                        ← Reusable Jinja functions
├── snapshots/                     ← Slowly changing dimension tracking
├── analyses/                      ← Ad-hoc queries (not built as models)
├── target/                        ← Compiled SQL output (auto-generated)
└── logs/                          ← Log files (auto-generated)
```

---

## File by File Explanation

### dbt_project.yml

**What:** The main configuration file for your project.

**Your file:**
```yaml
# Name of your project (used in references)
name: 'my_new_project'

# Version of your project (for documentation)
version: '1.0.0'

# Config file format version (always use 2)
config-version: 2

# Which profile to use for connections (must match profiles.yml)
profile: 'default'

# Where to find different types of files
model-paths: ["models"]
analysis-paths: ["analyses"]
test-paths: ["tests"]
seed-paths: ["seeds"]
macro-paths: ["macros"]
snapshot-paths: ["snapshots"]

# Where to put compiled SQL (auto-generated)
target-path: "target"

# Folders to delete when running `dbt clean`
clean-targets:
  - "target"
  - "dbt_packages"

# Default settings for models
models:
  my_new_project:           # Must match project name above
    example:                # Folder name under models/
      +materialized: table  # All models in example/ are tables by default
```

**Key points:**
- `profile: 'default'` must match the profile name in `profiles.yml`
- `models:` block sets defaults for models by folder

---

### profiles.yml

**What:** Connection settings for your data warehouse.

**Location:** Usually `~/.dbt/profiles.yml` (NOT in the project folder)

**Your file (in `C:\Users\Kamal Bura\.dbt\profiles.yml`):**
```yaml
default:                          # Profile name (matches dbt_project.yml)
  target: dev                     # Default target to use
  outputs:
    dev:                          # Target name
      type: bigquery              # Which adapter
      method: service-account     # Auth method
      project: saras-bigquery     # GCP project ID
      dataset: dbt_training       # BigQuery dataset (schema)
      keyfile: C:\Users\Kamal Bura\.dbt\service-account.json
      threads: 1                  # Parallel threads
```

**Profile structure:**
```yaml
profile_name:          # Referenced in dbt_project.yml
  target: target_name  # Default target
  outputs:
    target_name_1:     # e.g., dev
      ...settings...
    target_name_2:     # e.g., prod
      ...settings...
```

**Why separate targets?**
- `dev`: Your personal development dataset
- `staging`: Shared testing environment
- `prod`: Production data

Switch with: `dbt run --target prod`

---

### models/ Folder

**What:** Contains SQL files that become tables or views in your warehouse.

**Structure convention:**
```
models/
├── staging/           ← Light transformations from raw data
│   ├── stg_customers.sql
│   └── stg_orders.sql
├── intermediate/      ← Business logic, joins
│   └── int_customer_orders.sql
└── marts/             ← Final tables for analysts
    ├── core/
    │   └── dim_customers.sql
    └── finance/
        └── fct_revenue.sql
```

**Your current structure:**
```
models/
└── example/
    ├── my_first_dbt_model.sql
    ├── my_second_dbt_model.sql
    ├── customers_from_seed.sql
    └── schema.yml
```

---

### seeds/ Folder

**What:** CSV files that dbt uploads to your warehouse.

**Use cases:**
- Reference data (country codes, categories)
- Test data for development
- Static lookup tables

**Your files:**
```
seeds/
├── example_customers.csv    ← The data
└── schema.yml               ← Tests and documentation
```

**Running seeds:**
```powershell
dbt seed                            # All seeds
dbt seed --select example_customers # Specific seed
```

---

### tests/ Folder

**What:** Custom SQL tests (beyond built-in tests).

**Example custom test (`tests/assert_positive_amounts.sql`):**
```sql
-- This test FAILS if any rows are returned
SELECT order_id, amount
FROM {{ ref('orders') }}
WHERE amount < 0
```

---

### macros/ Folder

**What:** Reusable Jinja functions.

**Example macro (`macros/cents_to_dollars.sql`):**
```sql
{% macro cents_to_dollars(column_name) %}
    ({{ column_name }} / 100.0)
{% endmacro %}
```

**Using the macro in a model:**
```sql
SELECT
  order_id,
  {{ cents_to_dollars('amount_cents') }} AS amount_dollars
FROM raw_orders
```

---

### snapshots/ Folder

**What:** Track changes to data over time (Slowly Changing Dimensions).

**Example:** Track when a customer's email changes.

```sql
{% snapshot customers_snapshot %}

{{
  config(
    target_schema='snapshots',
    unique_key='id',
    strategy='check',
    check_cols=['email', 'name'],
  )
}}

SELECT * FROM {{ source('raw', 'customers') }}

{% endsnapshot %}
```

---

### analyses/ Folder

**What:** Ad-hoc queries that aren't materialized as tables.

**Use for:** One-off analysis scripts, exploratory queries.

```sql
-- analyses/customer_deep_dive.sql
-- This won't create a table, just stores the query

SELECT
  c.name,
  COUNT(o.id) as order_count
FROM {{ ref('dim_customers') }} c
LEFT JOIN {{ ref('fct_orders') }} o ON c.id = o.customer_id
GROUP BY 1
ORDER BY 2 DESC
LIMIT 100
```

**Compile (but don't run):**
```powershell
dbt compile --select customer_deep_dive
```

---

### target/ Folder (Auto-generated)

**What:** Contains compiled SQL (Jinja replaced with actual values).

**Useful for debugging:**
```
target/
├── compiled/
│   └── my_new_project/
│       └── models/
│           └── example/
│               └── customers_from_seed.sql  ← Compiled SQL
└── run/
    └── my_new_project/
        └── models/
            └── example/
                └── customers_from_seed.sql  ← SQL that was actually executed
```

---

### logs/ Folder (Auto-generated)

**What:** Log files from dbt runs.

**Useful for debugging failures.**

---

## schema.yml Files

**What:** Documentation and tests for models/seeds.

**Can be placed:**
- In any folder alongside SQL files
- Named `schema.yml` (convention) or any `*.yml`

**Example structure:**
```yaml
version: 2

models:
  - name: customers_from_seed
    description: "Customer data loaded from seed"
    columns:
      - name: id
        description: "Primary key"
        tests:
          - unique
          - not_null
      - name: email
        description: "Customer email address"
        tests:
          - not_null
```

---

## Summary

| Folder/File | Purpose |
|-------------|---------|
| `dbt_project.yml` | Project config |
| `profiles.yml` | Connection settings |
| `models/` | SQL transformations |
| `seeds/` | CSV data files |
| `tests/` | Custom SQL tests |
| `macros/` | Reusable functions |
| `snapshots/` | Track data changes |
| `analyses/` | Ad-hoc queries |
| `target/` | Compiled output |
| `logs/` | Run logs |
| `schema.yml` | Docs + tests |

---

**Next:** [03_models_and_materializations.md](03_models_and_materializations.md)
