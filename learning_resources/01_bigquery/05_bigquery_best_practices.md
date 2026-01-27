# BigQuery Best Practices

## Cost Optimization

BigQuery charges **$5 per TB scanned**. These practices save money:

### 1. Never Use SELECT *

```sql
-- ❌ BAD: Scans all columns
SELECT * FROM big_table;

-- ✅ GOOD: Scans only needed columns
SELECT id, name, email FROM big_table;
```

**Why:** Columnar storage means unused columns aren't free to ignore.

### 2. Use LIMIT When Exploring

```sql
-- ❌ BAD: Scans entire table
SELECT id, name FROM big_table;

-- ✅ GOOD: Still scans full table but returns fewer rows
SELECT id, name FROM big_table LIMIT 100;

-- ✅ BETTER: Use _PARTITIONTIME for partitioned tables
SELECT id, name FROM big_table
WHERE _PARTITIONTIME = '2023-01-01'
LIMIT 100;
```

**Note:** LIMIT doesn't reduce bytes scanned, but filtering on partition columns does.

### 3. Partition Large Tables

```sql
-- Create table partitioned by date
CREATE TABLE orders
PARTITION BY DATE(order_date)
AS SELECT * FROM raw_orders;

-- Query only scans relevant partitions
SELECT * FROM orders
WHERE order_date BETWEEN '2023-01-01' AND '2023-01-31';
```

**Rule of thumb:** Partition tables larger than 1 GB.

### 4. Cluster Frequently Filtered Columns

```sql
CREATE TABLE orders
PARTITION BY DATE(order_date)
CLUSTER BY customer_id, product_id
AS SELECT * FROM raw_orders;
```

**Best columns to cluster:**
- Columns in WHERE clauses
- Columns in JOIN conditions
- High cardinality columns (many unique values)

### 5. Avoid Repeated Subqueries

```sql
-- ❌ BAD: Subquery runs twice
SELECT
  (SELECT AVG(amount) FROM orders) AS avg_amount,
  amount - (SELECT AVG(amount) FROM orders) AS diff_from_avg
FROM orders;

-- ✅ GOOD: Calculate once with CTE
WITH stats AS (
  SELECT AVG(amount) AS avg_amount FROM orders
)
SELECT
  s.avg_amount,
  o.amount - s.avg_amount AS diff_from_avg
FROM orders o, stats s;
```

### 6. Use Approximate Functions for Large Data

```sql
-- Exact count distinct (expensive on large data)
SELECT COUNT(DISTINCT customer_id) FROM orders;

-- Approximate count distinct (faster, ~1% error)
SELECT APPROX_COUNT_DISTINCT(customer_id) FROM orders;
```

---

## Performance Optimization

### 1. Filter Early

```sql
-- ❌ BAD: Join first, filter later
SELECT c.name, o.amount
FROM customers c
JOIN orders o ON c.id = o.customer_id
WHERE o.order_date > '2023-01-01';

-- ✅ GOOD: Filter in a CTE first
WITH recent_orders AS (
  SELECT * FROM orders WHERE order_date > '2023-01-01'
)
SELECT c.name, o.amount
FROM customers c
JOIN recent_orders o ON c.id = o.customer_id;
```

### 2. Avoid CROSS JOINs

```sql
-- ❌ DANGEROUS: 1000 rows × 1000 rows = 1,000,000 rows
SELECT * FROM table_a CROSS JOIN table_b;
```

### 3. Use Appropriate Data Types

```sql
-- ❌ BAD: Storing dates as strings
SELECT * FROM orders WHERE order_date_string > '2023-01-01';

-- ✅ GOOD: Use proper DATE type
SELECT * FROM orders WHERE order_date > DATE '2023-01-01';
```

**Benefits:**
- Faster comparisons
- Smaller storage
- Enables partitioning

---

## Query Writing Best Practices

### 1. Use CTEs for Readability

```sql
-- ✅ GOOD: Clear, step-by-step logic
WITH
  active_customers AS (
    SELECT * FROM customers WHERE status = 'active'
  ),
  customer_orders AS (
    SELECT
      customer_id,
      COUNT(*) AS order_count,
      SUM(amount) AS total_spent
    FROM orders
    GROUP BY customer_id
  )

SELECT
  c.name,
  c.email,
  COALESCE(o.order_count, 0) AS order_count,
  COALESCE(o.total_spent, 0) AS total_spent
FROM active_customers c
LEFT JOIN customer_orders o ON c.id = o.customer_id;
```

### 2. Comment Your Queries

```sql
-- Calculate customer lifetime value
-- Includes only customers active in the last 90 days
WITH active_customers AS (
  SELECT *
  FROM customers
  WHERE last_active_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
)
...
```

### 3. Use Meaningful Aliases

```sql
-- ❌ BAD: What is 'a' and 'b'?
SELECT a.x, b.y FROM table1 a JOIN table2 b ON a.id = b.fk;

-- ✅ GOOD: Clear aliases
SELECT c.name, o.amount
FROM customers c
JOIN orders o ON c.id = o.customer_id;
```

### 4. Format Consistently

```sql
-- ✅ GOOD: Consistent formatting
SELECT
  customer_id,
  COUNT(*) AS order_count,
  SUM(amount) AS total_amount,
  AVG(amount) AS avg_amount
FROM orders
WHERE order_date >= '2023-01-01'
GROUP BY customer_id
HAVING COUNT(*) > 5
ORDER BY total_amount DESC
LIMIT 100;
```

---

## Schema Design Best Practices

### 1. Use Descriptive Column Names

```sql
-- ❌ BAD
CREATE TABLE t1 (
  c1 INT64,
  c2 STRING,
  c3 DATE
);

-- ✅ GOOD
CREATE TABLE customers (
  customer_id INT64,
  customer_name STRING,
  signup_date DATE
);
```

### 2. Include Metadata Columns

```sql
CREATE TABLE orders (
  order_id INT64,
  customer_id INT64,
  amount FLOAT64,
  -- Metadata
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
  updated_at TIMESTAMP,
  source_system STRING
);
```

### 3. Use Consistent Naming Conventions

| Element | Convention | Example |
|---------|------------|---------|
| Tables | snake_case, plural | `customers`, `order_items` |
| Columns | snake_case | `customer_id`, `created_at` |
| Primary keys | `id` or `table_id` | `id`, `customer_id` |
| Foreign keys | `referenced_table_id` | `customer_id`, `product_id` |
| Timestamps | `*_at` suffix | `created_at`, `updated_at` |
| Dates | `*_date` suffix | `order_date`, `signup_date` |
| Booleans | `is_*` or `has_*` prefix | `is_active`, `has_subscription` |

---

## Security Best Practices

### 1. Never Hardcode Credentials

```sql
-- ❌ NEVER DO THIS
SELECT * FROM EXTERNAL_QUERY(
  'connection',
  "SELECT * FROM users WHERE password = 'secret123'"
);
```

### 2. Use Column-Level Security for Sensitive Data

In BigQuery Console:
- Apply data masking policies
- Use authorized views to restrict access

### 3. Audit Access Regularly

- Check IAM permissions
- Review query logs
- Remove unused service accounts

---

## Monitoring and Debugging

### Check Query Cost Before Running

In BigQuery Console:
- Click "More" → "Query settings" → "Maximum bytes billed"
- Set a limit to prevent expensive queries

### View Query Execution Details

After running a query:
1. Click "Execution details" tab
2. Check "Slot time consumed"
3. Look for "Bytes shuffled" (high = inefficient JOINs)

### Use EXPLAIN

```sql
-- Shows query execution plan
EXPLAIN SELECT * FROM orders WHERE amount > 100;
```

---

## Summary Checklist

Before running a query, ask:

| Check | Action |
|-------|--------|
| ☐ Using SELECT *? | Specify columns needed |
| ☐ No WHERE clause on large table? | Add filters |
| ☐ Table not partitioned? | Consider partitioning |
| ☐ Complex subqueries? | Refactor to CTEs |
| ☐ First time running this query? | Test with LIMIT first |

---

**Next section:** [../02_dbt/01_what_is_dbt.md](../02_dbt/01_what_is_dbt.md)
