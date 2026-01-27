# What is BigQuery?

## The Simple Explanation

Imagine you have a massive spreadsheet with billions of rows. Your laptop would crash trying to open it. BigQuery is Google's solution: a **cloud data warehouse** that can query billions of rows in seconds.

## Key Points

| Concept | Explanation |
|---------|-------------|
| **Data Warehouse** | A database optimized for *reading* and *analyzing* data, not for frequent updates |
| **Cloud-based** | Runs on Google's servers, not your computer |
| **Serverless** | You don't manage servers; Google handles everything |
| **Pay-per-query** | You pay for the data you scan, not for idle time |

## How is BigQuery Different from a Regular Database?

| Traditional Database (e.g., MySQL) | BigQuery |
|------------------------------------|----------|
| Stores data in rows | Stores data in columns |
| Good for CRUD operations | Good for analytics |
| You manage the server | Google manages everything |
| Pay for the server 24/7 | Pay only when you query |

## Why "Columnar" Storage Matters

Traditional databases store data like this (row by row):
```
Row 1: [id=1, name="Alice", email="alice@example.com", signup_date="2023-01-05"]
Row 2: [id=2, name="Bob", email="bob@example.com", signup_date="2023-02-10"]
```

BigQuery stores data like this (column by column):
```
id column:          [1, 2, 3, ...]
name column:        ["Alice", "Bob", "Charlie", ...]
email column:       ["alice@...", "bob@...", "charlie@...", ...]
signup_date column: ["2023-01-05", "2023-02-10", ...]
```

**Why does this matter?**

If you run:
```sql
SELECT name FROM customers
```

- **Row storage:** Must read ALL columns for every row, then throw away what you don't need
- **Column storage:** Only reads the `name` column, skipping everything else

Result: Faster queries and lower cost!

## Your BigQuery Setup

You have:
- **Project:** `saras-bigquery` (like a folder that contains everything)
- **Dataset:** `dbt_training` (like a subfolder that contains tables)
- **Tables:** `example_customers`, `customers_from_seed` (actual data)

```
saras-bigquery (Project)
└── dbt_training (Dataset)
    ├── example_customers (Table - from your seed)
    └── customers_from_seed (Table - from your model)
```

## How to Access BigQuery

1. **Web Console:** https://console.cloud.google.com/bigquery
   - Visual interface
   - Run queries
   - Browse tables

2. **Command Line (`bq`):**
   ```powershell
   bq query --nouse_legacy_sql "SELECT * FROM \`saras-bigquery.dbt_training.example_customers\`"
   ```

3. **Through dbt:** (This is what we're learning!)
   - Write SQL files
   - dbt compiles and runs them on BigQuery

## Cost Model (Important!)

BigQuery charges based on:
1. **Storage:** $0.02 per GB per month (cheap)
2. **Queries:** $5 per TB scanned (this adds up!)

**Cost-saving tips:**
- Use `SELECT column1, column2` instead of `SELECT *`
- Use `LIMIT` when exploring data
- Partition large tables by date
- Use clustering for frequently filtered columns

## Summary

- BigQuery = Google's cloud data warehouse
- Columnar storage = fast analytics
- Serverless = no server management
- Pay-per-query = cost scales with usage
- Your setup: project `saras-bigquery` → dataset `dbt_training` → tables

---

**Next:** [02_bigquery_concepts.md](02_bigquery_concepts.md)
