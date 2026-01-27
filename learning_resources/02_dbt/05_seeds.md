# Seeds

## What are Seeds?

Seeds are CSV files that dbt loads into your data warehouse as tables.

```
seeds/
├── example_customers.csv    ← Your data
└── schema.yml               ← Documentation + tests
```

---

## When to Use Seeds

### ✅ Good Use Cases

| Use Case | Example |
|----------|---------|
| Reference/lookup data | Country codes, currency rates |
| Static mapping tables | Category mappings, department codes |
| Test data | Sample data for development |
| Small configuration | Feature flags, thresholds |

### ❌ Bad Use Cases

| Avoid When | Why |
|------------|-----|
| Large datasets (>1000 rows) | Use proper data loading tools |
| Frequently changing data | Seeds are for static data |
| Sensitive data | CSVs are committed to Git |

---

## Creating a Seed

### Step 1: Create the CSV File

```csv
# seeds/country_codes.csv
code,name,region
US,United States,North America
GB,United Kingdom,Europe
DE,Germany,Europe
JP,Japan,Asia
AU,Australia,Oceania
```

**Rules:**
- First row = column headers
- Use comma as delimiter
- UTF-8 encoding

### Step 2: Add Documentation (Optional)

```yaml
# seeds/schema.yml

version: 2

seeds:
  - name: country_codes
    description: "ISO country codes with regions"
    columns:
      - name: code
        description: "ISO 3166-1 alpha-2 country code"
        tests:
          - unique
          - not_null
      - name: name
        description: "Full country name"
      - name: region
        description: "Geographic region"
```

### Step 3: Load the Seed

```powershell
# Load all seeds
dbt seed

# Load specific seed
dbt seed --select country_codes

# Full refresh (drop and recreate)
dbt seed --full-refresh
```

---

## Your Seed Example

**seeds/example_customers.csv:**
```csv
id,name,email,signup_date
1,Alice,alice@example.com,2023-01-05
2,Bob,bob@example.com,2023-02-10
3,Charlie,charlie@example.com,2023-03-15
```

**What `dbt seed` does:**

1. Reads the CSV file
2. Infers data types:
   - `id` → INT64
   - `name` → STRING
   - `email` → STRING
   - `signup_date` → DATE
3. Creates table in BigQuery
4. Uploads the data

**Result:** `saras-bigquery.dbt_training.example_customers`

---

## Configuring Seeds

### In dbt_project.yml

```yaml
seeds:
  my_project:
    +schema: seeds              # Put in a specific schema
    country_codes:              # Specific seed config
      +column_types:
        code: STRING
        population: INT64
```

### Column Type Overrides

By default, dbt infers types. Override when needed:

```yaml
seeds:
  my_project:
    example_customers:
      +column_types:
        id: INT64
        signup_date: DATE
```

### Quoting

For special column names:

```yaml
seeds:
  my_project:
    my_seed:
      +quote_columns: true
```

---

## Using Seeds in Models

Seeds are referenced with `ref()`, just like models:

```sql
-- models/with_country_name.sql
select
  c.id,
  c.name,
  cc.name as country_name,
  cc.region
from {{ ref('customers') }} c
left join {{ ref('country_codes') }} cc on c.country_code = cc.code
```

---

## Seed vs Source

| Aspect | Seed | Source |
|--------|------|--------|
| Data stored in | Git (CSV file) | Data warehouse |
| Good for | Small, static data | Raw data from pipelines |
| Managed by | dbt (creates the table) | External systems |
| Reference with | `ref('seed_name')` | `source('src', 'table')` |

---

## Practical Tips

### 1. Keep Seeds Small

```
❌ customers_full_export.csv (50,000 rows)
   → Use a proper ETL tool

✅ customer_tiers.csv (5 rows)
   → Perfect for a seed
```

### 2. Version Control Advantage

Seeds in Git mean:
- Changes are tracked
- Easy rollback
- Review before deploy

### 3. Testing Seeds

Add tests in schema.yml:

```yaml
seeds:
  - name: country_codes
    columns:
      - name: code
        tests:
          - unique
          - not_null
          - accepted_values:
              values: ['US', 'GB', 'DE', 'JP', 'AU']
```

### 4. Updating Seeds

1. Edit the CSV file
2. Run `dbt seed --full-refresh`
3. Commit to Git

---

## Summary

| Command | What It Does |
|---------|--------------|
| `dbt seed` | Load all CSV files to warehouse |
| `dbt seed --select name` | Load specific seed |
| `dbt seed --full-refresh` | Drop and recreate tables |

**Key points:**
- Seeds = CSV files → tables
- Good for small, static data
- Reference with `ref('seed_name')`
- Define tests in schema.yml

---

**Next:** [06_tests.md](06_tests.md)
