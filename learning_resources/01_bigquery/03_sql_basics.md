# SQL Basics for BigQuery

## What is SQL?

SQL (Structured Query Language) is how you talk to databases. It reads like English:

```sql
SELECT name, email FROM customers WHERE signup_date > '2023-01-01'
```

"Select the name and email from customers where signup date is after January 1, 2023."

## The Four Main Operations (CRUD)

| Operation | SQL Command | Meaning |
|-----------|-------------|---------|
| **C**reate | `INSERT` | Add new rows |
| **R**ead | `SELECT` | Get data |
| **U**pdate | `UPDATE` | Change existing rows |
| **D**elete | `DELETE` | Remove rows |

**In analytics (and dbt), you mainly use SELECT.**

---

## SELECT: Reading Data

### Basic SELECT

```sql
-- Get all columns from a table
SELECT * FROM example_customers;

-- Get specific columns
SELECT id, name FROM example_customers;
```

### Anatomy of a SELECT Statement

```sql
SELECT      -- What columns to show
  column1,
  column2
FROM        -- Which table to read from
  my_table
WHERE       -- Filter rows (optional)
  condition
GROUP BY    -- Group rows together (optional)
  column1
HAVING      -- Filter groups (optional)
  condition
ORDER BY    -- Sort results (optional)
  column1
LIMIT       -- How many rows to return (optional)
  10;
```

### Execution Order (Important!)

SQL doesn't run top-to-bottom. The actual order is:

1. `FROM` - Pick the table
2. `WHERE` - Filter rows
3. `GROUP BY` - Group rows
4. `HAVING` - Filter groups
5. `SELECT` - Pick columns
6. `ORDER BY` - Sort
7. `LIMIT` - Limit rows

**Why this matters:**
```sql
-- This WORKS (WHERE runs before SELECT)
SELECT id, name FROM customers WHERE signup_date > '2023-01-01';

-- This FAILS (WHERE can't see the alias defined in SELECT)
SELECT id, name, signup_date AS sd FROM customers WHERE sd > '2023-01-01';
-- Error: sd is not recognized
```

---

## Filtering with WHERE

### Comparison Operators

```sql
-- Equal
SELECT * FROM customers WHERE id = 1;

-- Not equal
SELECT * FROM customers WHERE id != 1;
-- or
SELECT * FROM customers WHERE id <> 1;

-- Greater than, less than
SELECT * FROM customers WHERE id > 5;
SELECT * FROM customers WHERE signup_date < '2023-06-01';

-- Greater than or equal, less than or equal
SELECT * FROM customers WHERE id >= 5;
SELECT * FROM customers WHERE id <= 10;
```

### BETWEEN

```sql
-- Inclusive range
SELECT * FROM customers
WHERE signup_date BETWEEN '2023-01-01' AND '2023-12-31';
```

### IN

```sql
-- Match any value in a list
SELECT * FROM customers
WHERE name IN ('Alice', 'Bob', 'Charlie');
```

### LIKE (Pattern Matching)

```sql
-- % = any characters
-- _ = single character

-- Names starting with 'A'
SELECT * FROM customers WHERE name LIKE 'A%';

-- Names ending with 'e'
SELECT * FROM customers WHERE name LIKE '%e';

-- Names containing 'li'
SELECT * FROM customers WHERE name LIKE '%li%';

-- Exactly 5 characters
SELECT * FROM customers WHERE name LIKE '_____';
```

### NULL Handling

```sql
-- NULL means "unknown" or "missing"
-- You cannot use = with NULL

-- WRONG
SELECT * FROM customers WHERE email = NULL;

-- CORRECT
SELECT * FROM customers WHERE email IS NULL;
SELECT * FROM customers WHERE email IS NOT NULL;
```

### Combining Conditions (AND, OR, NOT)

```sql
-- Both conditions must be true
SELECT * FROM customers
WHERE name = 'Alice' AND signup_date > '2023-01-01';

-- Either condition can be true
SELECT * FROM customers
WHERE name = 'Alice' OR name = 'Bob';

-- Negate a condition
SELECT * FROM customers
WHERE NOT name = 'Alice';

-- Use parentheses for complex logic
SELECT * FROM customers
WHERE (name = 'Alice' OR name = 'Bob')
  AND signup_date > '2023-01-01';
```

---

## Aggregation with GROUP BY

### Common Aggregate Functions

| Function | Description |
|----------|-------------|
| `COUNT(*)` | Number of rows |
| `COUNT(column)` | Non-NULL values in column |
| `SUM(column)` | Total of values |
| `AVG(column)` | Average of values |
| `MIN(column)` | Smallest value |
| `MAX(column)` | Largest value |

### Examples

```sql
-- Count all customers
SELECT COUNT(*) FROM customers;

-- Count by signup month
SELECT
  DATE_TRUNC(signup_date, MONTH) AS month,
  COUNT(*) AS customer_count
FROM customers
GROUP BY month
ORDER BY month;
```

### HAVING (Filter After Grouping)

```sql
-- Only show months with more than 10 signups
SELECT
  DATE_TRUNC(signup_date, MONTH) AS month,
  COUNT(*) AS customer_count
FROM customers
GROUP BY month
HAVING COUNT(*) > 10;
```

---

## Sorting with ORDER BY

```sql
-- Ascending (A-Z, 0-9, oldest first) — default
SELECT * FROM customers ORDER BY name ASC;

-- Descending (Z-A, 9-0, newest first)
SELECT * FROM customers ORDER BY signup_date DESC;

-- Multiple columns
SELECT * FROM customers ORDER BY name ASC, signup_date DESC;
```

---

## Limiting Results with LIMIT

```sql
-- First 10 rows
SELECT * FROM customers LIMIT 10;

-- Skip first 5, then get 10
SELECT * FROM customers LIMIT 10 OFFSET 5;
```

---

## Aliases (Renaming)

```sql
-- Column alias
SELECT name AS customer_name FROM customers;

-- Table alias (useful in JOINs)
SELECT c.name, c.email
FROM customers AS c;

-- AS is optional but recommended for clarity
SELECT name customer_name FROM customers; -- works but less clear
```

---

## JOINs (Combining Tables)

### Visual Explanation

```
customers          orders
+----+-------+     +----+-------------+--------+
| id | name  |     | id | customer_id | amount |
+----+-------+     +----+-------------+--------+
| 1  | Alice |     | 1  | 1           | 100    |
| 2  | Bob   |     | 2  | 1           | 200    |
| 3  | Carol |     | 3  | 2           | 150    |
+----+-------+     +----+-------------+--------+
```

### INNER JOIN (Most Common)

Only rows that match in **both** tables.

```sql
SELECT c.name, o.amount
FROM customers c
INNER JOIN orders o ON c.id = o.customer_id;

-- Result:
-- Alice | 100
-- Alice | 200
-- Bob   | 150
-- (Carol is missing - she has no orders)
```

### LEFT JOIN

All rows from **left** table, matching rows from right (or NULL).

```sql
SELECT c.name, o.amount
FROM customers c
LEFT JOIN orders o ON c.id = o.customer_id;

-- Result:
-- Alice | 100
-- Alice | 200
-- Bob   | 150
-- Carol | NULL   ← Carol appears with NULL
```

### RIGHT JOIN

All rows from **right** table, matching rows from left (or NULL).

### FULL OUTER JOIN

All rows from **both** tables, with NULLs where there's no match.

### CROSS JOIN

Every row from left × every row from right (rarely used).

---

## Subqueries

A query inside another query.

```sql
-- Subquery in WHERE
SELECT * FROM customers
WHERE id IN (SELECT customer_id FROM orders WHERE amount > 100);

-- Subquery in FROM (derived table)
SELECT avg_amount FROM (
  SELECT customer_id, AVG(amount) as avg_amount
  FROM orders
  GROUP BY customer_id
);
```

---

## Common Table Expressions (CTEs)

A cleaner way to write subqueries. **dbt uses CTEs heavily.**

```sql
-- WITH clause defines a CTE
WITH high_value_orders AS (
  SELECT customer_id, SUM(amount) as total
  FROM orders
  GROUP BY customer_id
  HAVING SUM(amount) > 500
)

SELECT c.name, h.total
FROM customers c
JOIN high_value_orders h ON c.id = h.customer_id;
```

**Why CTEs are better than subqueries:**
- More readable
- Can reference the same CTE multiple times
- Easier to debug step-by-step

---

## Summary

| Command | Purpose |
|---------|---------|
| `SELECT` | Read data |
| `FROM` | Specify table |
| `WHERE` | Filter rows |
| `GROUP BY` | Aggregate rows |
| `HAVING` | Filter aggregated results |
| `ORDER BY` | Sort results |
| `LIMIT` | Limit row count |
| `JOIN` | Combine tables |
| `WITH` | Define CTEs |

---

**Next:** [04_bigquery_syntax.md](04_bigquery_syntax.md)
