# BigQuery Core Concepts

## The Hierarchy

```
Organization (optional - for enterprises)
└── Project
    └── Dataset
        └── Table / View
```

### 1. Project

**What:** A container for all your Google Cloud resources.

**Think of it as:** A company or department.

**In your case:** `saras-bigquery`

**Key facts:**
- Has a unique ID (like `saras-bigquery`)
- Billing is at the project level
- Permissions can be set at project level

### 2. Dataset

**What:** A container for tables and views within a project.

**Think of it as:** A folder or a database schema.

**In your case:** `dbt_training`

**Key facts:**
- Has a geographic location (US, EU, etc.)
- Once created, location cannot change
- Tables inside inherit permissions from dataset
- dbt creates tables inside this dataset

### 3. Table

**What:** Structured data with rows and columns.

**Types of tables:**

| Type | Description | Example |
|------|-------------|---------|
| **Native table** | Data stored in BigQuery | Your `example_customers` |
| **External table** | Data in GCS, reads on query | CSV files in Cloud Storage |
| **View** | Saved query, no data stored | `my_second_dbt_model` (if materialized as view) |
| **Materialized view** | Cached query results | Pre-computed aggregations |

### 4. View

**What:** A saved SQL query that looks like a table.

**How it works:**
```sql
-- Creating a view (conceptually)
CREATE VIEW my_view AS
SELECT id, name FROM customers WHERE active = true;

-- When you query the view, BigQuery runs the underlying query
SELECT * FROM my_view;
-- Actually runs: SELECT * FROM (SELECT id, name FROM customers WHERE active = true)
```

**Pros:**
- No storage cost
- Always shows fresh data

**Cons:**
- Query cost every time
- Can be slow for complex queries

## Data Types in BigQuery

### Common Types

| Type | Description | Example |
|------|-------------|---------|
| `STRING` | Text | `'Alice'` |
| `INT64` | Integer | `123` |
| `FLOAT64` | Decimal | `3.14` |
| `BOOL` | True/False | `TRUE` |
| `DATE` | Date only | `DATE '2023-01-05'` |
| `DATETIME` | Date + time, no timezone | `DATETIME '2023-01-05 10:30:00'` |
| `TIMESTAMP` | Date + time + timezone | `TIMESTAMP '2023-01-05 10:30:00 UTC'` |
| `ARRAY` | List of values | `[1, 2, 3]` |
| `STRUCT` | Nested fields | `STRUCT('Alice', 25)` |

### Your Seed Data Types

In `example_customers`:
- `id` → `INT64`
- `name` → `STRING`
- `email` → `STRING`
- `signup_date` → `DATE`

## Partitioning

**What:** Dividing a table into segments based on a column (usually date).

**Why:** Queries scan only relevant partitions, reducing cost and time.

```sql
-- A partitioned table
CREATE TABLE orders
PARTITION BY DATE(order_date)
AS SELECT * FROM raw_orders;

-- This query scans only 2 days, not the whole table
SELECT * FROM orders
WHERE order_date BETWEEN '2023-01-01' AND '2023-01-02';
```

**Best for:** Large tables with date/time columns.

## Clustering

**What:** Organizing data within partitions by specified columns.

**Why:** Queries filtering on clustered columns are faster and cheaper.

```sql
CREATE TABLE orders
PARTITION BY DATE(order_date)
CLUSTER BY customer_id, product_id
AS SELECT * FROM raw_orders;
```

**Best for:** Columns frequently used in WHERE, JOIN, GROUP BY.

## Jobs

**What:** An action that BigQuery runs (query, load, export).

Every time you:
- Run a query → Query job
- Load data from CSV → Load job
- Export to GCS → Export job

You can monitor jobs in the BigQuery console under "Job history".

## IAM (Permissions)

**Common roles:**

| Role | Can Do |
|------|--------|
| `BigQuery Data Viewer` | Read tables |
| `BigQuery Data Editor` | Read + write tables |
| `BigQuery Job User` | Run queries |
| `BigQuery Admin` | Everything |

**Your service account** (`billi-bq@saras-bigquery.iam.gserviceaccount.com`) needs:
- `BigQuery Data Editor` (to create tables)
- `BigQuery Job User` (to run queries)

## Fully Qualified Table Names

In BigQuery, tables are referenced as:

```
project.dataset.table
```

Example:
```sql
SELECT * FROM `saras-bigquery.dbt_training.example_customers`
```

**Note the backticks!** Required when project/dataset/table names contain special characters or start with numbers.

## Summary

| Concept | Your Setup |
|---------|------------|
| Project | `saras-bigquery` |
| Dataset | `dbt_training` |
| Tables | `example_customers`, `customers_from_seed` |
| Service Account | `billi-bq@saras-bigquery.iam.gserviceaccount.com` |

---

**Next:** [03_sql_basics.md](03_sql_basics.md)
