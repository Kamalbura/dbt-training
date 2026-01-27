# BigQuery-Specific SQL Syntax

BigQuery uses **Standard SQL** with some unique features. This file covers syntax that's specific to BigQuery.

---

## Backticks for Table Names

In BigQuery, use backticks around fully qualified table names:

```sql
-- Standard way
SELECT * FROM `project.dataset.table`;

-- Your tables
SELECT * FROM `saras-bigquery.dbt_training.example_customers`;
```

**When are backticks required?**
- Project/dataset/table names with hyphens (`saras-bigquery`)
- Names starting with numbers
- Names with special characters

**When can you skip them?**
- Within the same project, you can omit the project name
- If using the BigQuery console with a default dataset set

---

## Date and Time Functions

### Current Date/Time

```sql
SELECT CURRENT_DATE();        -- 2026-01-27
SELECT CURRENT_DATETIME();    -- 2026-01-27 10:30:45
SELECT CURRENT_TIMESTAMP();   -- 2026-01-27 10:30:45 UTC
```

### Extracting Parts

```sql
SELECT
  signup_date,
  EXTRACT(YEAR FROM signup_date) AS year,
  EXTRACT(MONTH FROM signup_date) AS month,
  EXTRACT(DAY FROM signup_date) AS day,
  EXTRACT(DAYOFWEEK FROM signup_date) AS day_of_week  -- 1=Sunday
FROM example_customers;
```

### Formatting Dates

```sql
SELECT FORMAT_DATE('%Y-%m-%d', signup_date) AS formatted;
-- Result: '2023-01-05'

SELECT FORMAT_DATE('%B %d, %Y', signup_date) AS formatted;
-- Result: 'January 05, 2023'
```

### Date Arithmetic

```sql
-- Add/subtract intervals
SELECT DATE_ADD(signup_date, INTERVAL 30 DAY) AS plus_30_days;
SELECT DATE_SUB(signup_date, INTERVAL 1 MONTH) AS minus_1_month;

-- Difference between dates
SELECT DATE_DIFF(CURRENT_DATE(), signup_date, DAY) AS days_since_signup;
```

### Truncating Dates

```sql
-- Round down to start of period
SELECT DATE_TRUNC(signup_date, MONTH) AS month_start;
-- 2023-01-05 → 2023-01-01

SELECT DATE_TRUNC(signup_date, YEAR) AS year_start;
-- 2023-01-05 → 2023-01-01
```

---

## String Functions

### Length and Case

```sql
SELECT
  name,
  LENGTH(name) AS name_length,
  UPPER(name) AS uppercase,
  LOWER(name) AS lowercase,
  INITCAP(name) AS title_case
FROM example_customers;
```

### Substring and Position

```sql
SELECT
  email,
  SUBSTR(email, 1, 5) AS first_5_chars,           -- 'alice'
  STRPOS(email, '@') AS at_position,               -- 6 (1-indexed)
  SPLIT(email, '@')[OFFSET(0)] AS username,        -- 'alice'
  SPLIT(email, '@')[OFFSET(1)] AS domain           -- 'example.com'
FROM example_customers;
```

### Concatenation

```sql
-- Using CONCAT
SELECT CONCAT(name, ' <', email, '>') AS formatted;
-- Result: 'Alice <alice@example.com>'

-- Using || operator
SELECT name || ' <' || email || '>' AS formatted;
```

### Trimming and Padding

```sql
SELECT
  TRIM('  hello  ') AS trimmed,           -- 'hello'
  LTRIM('  hello') AS left_trimmed,       -- 'hello'
  RTRIM('hello  ') AS right_trimmed,      -- 'hello'
  LPAD('42', 5, '0') AS left_padded,      -- '00042'
  RPAD('42', 5, '0') AS right_padded      -- '42000'
;
```

### Regular Expressions

```sql
-- Check if matches pattern
SELECT REGEXP_CONTAINS(email, r'^[a-z]+@') AS starts_with_letters;

-- Extract matching part
SELECT REGEXP_EXTRACT(email, r'^([a-z]+)@') AS username;

-- Replace matching part
SELECT REGEXP_REPLACE(email, r'@.*', '@masked.com') AS masked_email;
```

---

## NULL Handling

### IFNULL and COALESCE

```sql
-- Replace NULL with a default value
SELECT IFNULL(email, 'no-email@unknown.com') AS email;

-- COALESCE: first non-NULL value
SELECT COALESCE(phone, mobile, email, 'no contact') AS contact;
```

### NULLIF

```sql
-- Return NULL if values are equal
SELECT NULLIF(status, 'unknown') AS status;
-- If status = 'unknown', returns NULL; otherwise returns status
```

---

## Conditional Logic

### CASE Expression

```sql
SELECT
  name,
  signup_date,
  CASE
    WHEN signup_date < '2023-03-01' THEN 'early_adopter'
    WHEN signup_date < '2023-06-01' THEN 'mid_adopter'
    ELSE 'late_adopter'
  END AS cohort
FROM example_customers;
```

### IF Function

```sql
-- Simpler for two-way logic
SELECT
  name,
  IF(email IS NOT NULL, 'has_email', 'no_email') AS email_status
FROM example_customers;
```

---

## Array Functions

BigQuery supports arrays (lists of values).

```sql
-- Creating an array
SELECT [1, 2, 3] AS my_array;

-- Array from query results
SELECT ARRAY_AGG(name) AS all_names FROM example_customers;

-- Accessing elements (0-indexed with OFFSET, 1-indexed with ORDINAL)
SELECT my_array[OFFSET(0)] AS first_element;   -- 1
SELECT my_array[ORDINAL(1)] AS first_element;  -- 1

-- Flattening an array (UNNEST)
SELECT *
FROM UNNEST([1, 2, 3]) AS number;
-- Result: 3 rows with values 1, 2, 3
```

---

## Struct (Nested Records)

Structs are like mini-tables inside a column.

```sql
-- Creating a struct
SELECT STRUCT('Alice' AS name, 25 AS age) AS person;

-- Accessing struct fields
SELECT person.name, person.age
FROM (SELECT STRUCT('Alice' AS name, 25 AS age) AS person);
```

---

## Window Functions

Perform calculations across related rows without collapsing them.

### ROW_NUMBER

```sql
-- Number rows within each group
SELECT
  name,
  signup_date,
  ROW_NUMBER() OVER (ORDER BY signup_date) AS signup_order
FROM example_customers;
```

### Partitioning

```sql
-- Row number within each cohort
SELECT
  name,
  cohort,
  signup_date,
  ROW_NUMBER() OVER (PARTITION BY cohort ORDER BY signup_date) AS rank_in_cohort
FROM customers_with_cohort;
```

### Running Totals

```sql
SELECT
  name,
  amount,
  SUM(amount) OVER (ORDER BY order_date) AS running_total
FROM orders;
```

### Lead and Lag

```sql
SELECT
  order_date,
  amount,
  LAG(amount, 1) OVER (ORDER BY order_date) AS previous_amount,
  LEAD(amount, 1) OVER (ORDER BY order_date) AS next_amount
FROM orders;
```

---

## Creating Tables

```sql
-- Create empty table with schema
CREATE TABLE `project.dataset.my_table` (
  id INT64,
  name STRING,
  created_at TIMESTAMP
);

-- Create table from query (CTAS)
CREATE TABLE `project.dataset.new_table` AS
SELECT * FROM `project.dataset.old_table` WHERE active = true;

-- Create or replace
CREATE OR REPLACE TABLE `project.dataset.my_table` AS
SELECT * FROM source;
```

**Note:** In dbt, you rarely write CREATE TABLE directly. dbt handles it based on your materialization setting.

---

## DML (Data Modification)

### INSERT

```sql
INSERT INTO `project.dataset.my_table` (id, name)
VALUES (1, 'Alice'), (2, 'Bob');
```

### UPDATE

```sql
UPDATE `project.dataset.my_table`
SET name = 'Updated Name'
WHERE id = 1;
```

### DELETE

```sql
DELETE FROM `project.dataset.my_table`
WHERE id = 1;
```

### MERGE (Upsert)

```sql
MERGE INTO target AS t
USING source AS s
ON t.id = s.id
WHEN MATCHED THEN
  UPDATE SET t.name = s.name
WHEN NOT MATCHED THEN
  INSERT (id, name) VALUES (s.id, s.name);
```

**Note:** dbt uses MERGE internally for incremental models.

---

## Summary

| Category | Key Functions |
|----------|---------------|
| Date | `DATE_TRUNC`, `DATE_DIFF`, `EXTRACT`, `FORMAT_DATE` |
| String | `CONCAT`, `SUBSTR`, `SPLIT`, `REGEXP_EXTRACT` |
| NULL | `IFNULL`, `COALESCE`, `NULLIF` |
| Conditional | `CASE`, `IF` |
| Array | `ARRAY_AGG`, `UNNEST`, `OFFSET` |
| Window | `ROW_NUMBER`, `SUM OVER`, `LAG`, `LEAD` |

---

**Next:** [05_bigquery_best_practices.md](05_bigquery_best_practices.md)
