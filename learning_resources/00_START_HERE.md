# 📚 dbt + BigQuery Learning Resources

Welcome! This folder contains everything you need to learn dbt and BigQuery from absolute zero.

## How to Use This Guide

Read the files **in order** (by number). Each stage builds on the previous one.

```
learning_resources/
├── 00_START_HERE.md              ← You are here
├── 01_bigquery/                  ← Learn BigQuery first
│   ├── 01_what_is_bigquery.md
│   ├── 02_bigquery_concepts.md
│   ├── 03_sql_basics.md
│   ├── 04_bigquery_syntax.md
│   └── 05_bigquery_best_practices.md
├── 02_dbt/                       ← Then learn dbt
│   ├── 01_what_is_dbt.md
│   ├── 02_dbt_project_structure.md
│   ├── 03_models_and_materializations.md
│   ├── 04_ref_and_source.md
│   ├── 05_seeds.md
│   ├── 06_tests.md
│   ├── 07_documentation.md
│   └── 08_dbt_best_practices.md
├── 03_hands_on/                  ← Practice exercises
│   ├── exercise_01_first_model.md
│   ├── exercise_02_add_tests.md
│   └── exercise_03_incremental.md
└── 04_reference/                 ← Quick reference sheets
    ├── dbt_commands_cheatsheet.md
    ├── jinja_basics.md
    └── common_errors.md
```

## Your Learning Path

| Stage | Topic | Time Estimate |
|-------|-------|---------------|
| 1 | BigQuery Basics | 30-45 min |
| 2 | dbt Fundamentals | 1-2 hours |
| 3 | Hands-on Exercises | 1 hour |
| 4 | Reference (ongoing) | As needed |

## Prerequisites

- ✅ Python installed (you have this)
- ✅ dbt installed in conda env `dbt-env` (you have this)
- ✅ BigQuery project with service account (you have this: `saras-bigquery`)
- ✅ `dbt debug` passing (you verified this)

## What You Already Accomplished

1. Created a dbt project from dbt Cloud
2. Cloned it locally
3. Configured `profiles.yml` with BigQuery credentials
4. Ran `dbt debug` successfully
5. Loaded a seed (`example_customers`)
6. Built a model (`customers_from_seed`)
7. Ran tests and they passed

Now let's understand **WHY** each of those steps worked!

---

**Start here:** [01_bigquery/01_what_is_bigquery.md](01_bigquery/01_what_is_bigquery.md)
