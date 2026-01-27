# Jinja Basics for dbt

## What is Jinja?

Jinja is a templating language that adds programming features to your SQL:
- Variables
- Conditionals
- Loops
- Macros (functions)

dbt uses Jinja to make SQL dynamic and reusable.

---

## Jinja Syntax

### Three Types of Tags

| Tag | Purpose | Example |
|-----|---------|---------|
| `{{ }}` | Output/expression | `{{ ref('model') }}` |
| `{% %}` | Statement/logic | `{% if condition %}` |
| `{# #}` | Comment | `{# This is a comment #}` |

---

## Expressions: `{{ }}`

Expressions output a value.

```sql
-- Reference a model
SELECT * FROM {{ ref('customers') }}

-- Output a variable
WHERE date >= '{{ var("start_date") }}'

-- Call a macro
{{ cents_to_dollars('amount') }}
```

---

## Statements: `{% %}`

Statements control logic but don't output text.

### If/Else

```sql
SELECT
    id,
    name,
    {% if target.name == 'dev' %}
        'development' as environment
    {% else %}
        'production' as environment
    {% endif %}
FROM customers
```

### For Loops

```sql
SELECT
    id,
    {% for col in ['name', 'email', 'phone'] %}
        {{ col }}{% if not loop.last %},{% endif %}
    {% endfor %}
FROM customers
```

**Output:**
```sql
SELECT
    id,
    name,
    email,
    phone
FROM customers
```

---

## dbt-Specific Functions

### ref()

Reference another model or seed:

```sql
SELECT * FROM {{ ref('stg_customers') }}
```

**Compiled:**
```sql
SELECT * FROM `project.dataset.stg_customers`
```

### source()

Reference external tables:

```sql
SELECT * FROM {{ source('raw', 'customers') }}
```

### config()

Set model configuration:

```sql
{{ config(materialized='table', tags=['daily']) }}

SELECT * FROM ...
```

### this

Reference the current model's table (for incrementals):

```sql
{% if is_incremental() %}
WHERE updated_at > (SELECT MAX(updated_at) FROM {{ this }})
{% endif %}
```

### target

Access target/environment info:

```sql
{% if target.name == 'prod' %}
    -- Production-only logic
{% endif %}

-- Available properties:
-- target.name (dev, prod, etc.)
-- target.schema
-- target.database
-- target.type (bigquery, postgres, etc.)
```

### var()

Access project variables:

```yaml
# dbt_project.yml
vars:
  start_date: '2020-01-01'
  enable_feature: true
```

```sql
WHERE created_at >= '{{ var("start_date") }}'

{% if var("enable_feature") %}
    -- Feature-specific SQL
{% endif %}
```

### env_var()

Access environment variables:

```sql
-- Useful for secrets
{{ env_var('DB_PASSWORD') }}

-- With default
{{ env_var('OPTIONAL_VAR', 'default_value') }}
```

---

## Macros

Reusable functions defined in `macros/` folder.

### Defining a Macro

```sql
-- macros/cents_to_dollars.sql

{% macro cents_to_dollars(column_name, precision=2) %}
    ROUND({{ column_name }} / 100.0, {{ precision }})
{% endmacro %}
```

### Using the Macro

```sql
SELECT
    order_id,
    {{ cents_to_dollars('amount_cents') }} as amount_dollars,
    {{ cents_to_dollars('tax_cents', 4) }} as tax_dollars
FROM orders
```

**Compiled:**
```sql
SELECT
    order_id,
    ROUND(amount_cents / 100.0, 2) as amount_dollars,
    ROUND(tax_cents / 100.0, 4) as tax_dollars
FROM orders
```

---

## Control Structures

### If/Elif/Else

```sql
{% if condition1 %}
    -- Code for condition1
{% elif condition2 %}
    -- Code for condition2
{% else %}
    -- Default code
{% endif %}
```

### For Loops

```sql
{% for item in list %}
    {{ item }}
{% endfor %}
```

**Loop Variables:**

| Variable | Description |
|----------|-------------|
| `loop.index` | Current iteration (1-based) |
| `loop.index0` | Current iteration (0-based) |
| `loop.first` | True if first iteration |
| `loop.last` | True if last iteration |
| `loop.length` | Total number of items |

```sql
{% for col in columns %}
    {{ col }}{% if not loop.last %},{% endif %}
{% endfor %}
```

---

## Filters

Filters transform values:

```sql
-- Uppercase
{{ "hello" | upper }}  -- HELLO

-- Default value
{{ my_var | default('fallback') }}

-- Length
{% if my_list | length > 0 %}

-- Join list
{{ ['a', 'b', 'c'] | join(', ') }}  -- a, b, c

-- Trim whitespace
{{ "  hello  " | trim }}  -- hello
```

---

## Common Patterns

### Dynamic Column Selection

```sql
{% set columns = ['id', 'name', 'email', 'created_at'] %}

SELECT
    {% for col in columns %}
        {{ col }}{% if not loop.last %},{% endif %}
    {% endfor %}
FROM customers
```

### Conditional WHERE Clauses

```sql
SELECT *
FROM orders
WHERE 1=1  -- Always true, makes adding conditions easy
    {% if var('filter_status', none) is not none %}
        AND status = '{{ var("filter_status") }}'
    {% endif %}
    {% if target.name == 'dev' %}
        AND order_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
    {% endif %}
```

### Generate Union All

```sql
{% set tables = ['orders_2021', 'orders_2022', 'orders_2023'] %}

{% for table in tables %}
    SELECT * FROM {{ source('raw', table) }}
    {% if not loop.last %}UNION ALL{% endif %}
{% endfor %}
```

### Set Variables

```sql
{% set my_var = 'value' %}
{% set my_list = ['a', 'b', 'c'] %}
{% set my_dict = {'key1': 'value1', 'key2': 'value2'} %}

-- Use them
SELECT '{{ my_var }}' as col1
```

---

## Whitespace Control

Jinja tags can leave unwanted whitespace. Control with `-`:

```sql
-- Without control (extra newlines)
{% for item in items %}
{{ item }}
{% endfor %}

-- With control (cleaner output)
{%- for item in items -%}
{{ item }}
{%- endfor -%}
```

---

## Debugging Jinja

### Print to Logs

```sql
{{ log("Debug: my_var = " ~ my_var, info=true) }}
```

### View Compiled SQL

```powershell
dbt compile --select my_model
cat target/compiled/my_project/models/my_model.sql
```

### Use run_query for Testing

```sql
{% set result = run_query("SELECT COUNT(*) FROM my_table") %}
{% if execute %}
    {% set row_count = result.columns[0].values()[0] %}
    {{ log("Row count: " ~ row_count, info=true) }}
{% endif %}
```

---

## Common Mistakes

### Wrong: Mixing SQL and Jinja Quotes

```sql
-- ❌ WRONG
WHERE name = '{{ "Bob" }}'  -- Double quotes inside single

-- ✅ RIGHT
WHERE name = '{{ "Bob" }}'  -- This actually works
WHERE name = 'Bob'  -- Or just use SQL directly
```

### Wrong: Forgetting execute Check

```sql
-- ❌ WRONG (runs during parsing)
{% set result = run_query("SELECT ...") %}
{% set value = result.columns[0].values()[0] %}

-- ✅ RIGHT (only runs during execution)
{% set result = run_query("SELECT ...") %}
{% if execute %}
    {% set value = result.columns[0].values()[0] %}
{% endif %}
```

### Wrong: Spaces in ref()

```sql
-- ❌ WRONG
{{ ref( 'my_model' ) }}

-- ✅ RIGHT
{{ ref('my_model') }}
```

---

## Summary

| Syntax | Purpose |
|--------|---------|
| `{{ }}` | Output expression |
| `{% %}` | Logic/statements |
| `{# #}` | Comments |
| `ref()` | Reference model |
| `source()` | Reference source |
| `config()` | Model configuration |
| `var()` | Access variables |
| `target` | Environment info |
| `this` | Current model table |

---

**Back to:** [../00_START_HERE.md](../00_START_HERE.md)
