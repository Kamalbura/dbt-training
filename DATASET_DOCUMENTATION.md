# dbt Training Project - Dataset & Tables Documentation

## 📊 Overview

This project uses the **Stack Overflow Public Dataset** from BigQuery to demonstrate real-world data engineering with dbt. The dataset contains millions of questions, answers, users, and tags from Stack Overflow — perfect for learning data transformation patterns.

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      BigQuery Public Data                                │
│                 bigquery-public-data.stackoverflow                       │
│  ┌──────────────┐ ┌──────────────┐ ┌────────┐ ┌──────────────┐         │
│  │posts_questions│ │posts_answers │ │ users  │ │    tags      │         │
│  └──────────────┘ └──────────────┘ └────────┘ └──────────────┘         │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼ source()
┌─────────────────────────────────────────────────────────────────────────┐
│                         STAGING LAYER                                    │
│                    saras-bigquery.dbt_training_staging                   │
│  ┌──────────────────────────┐ ┌────────────────────┐ ┌───────────────┐ │
│  │stg_stackoverflow__questions│ │stg_stackoverflow__users│stg_stackoverflow__tags│
│  └──────────────────────────┘ └────────────────────┘ └───────────────┘ │
│         • Cleaned             • Filtered (rep>=100)    • Filtered (DE tags)  │
│         • Renamed             • Tiered by reputation   • Categorized         │
│         • DE topics only      • 1.2M users             • 29 tags             │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼ ref()
┌─────────────────────────────────────────────────────────────────────────┐
│                          MARTS LAYER                                     │
│                    saras-bigquery.dbt_training_analytics                 │
│      ┌────────────────────────┐        ┌─────────────────────────┐      │
│      │  fct_questions_summary │        │        dim_tags         │      │
│      │   • Daily aggregates   │        │   • Popularity ranking  │      │
│      │   • Score breakdown    │        │   • Category grouping   │      │
│      │   • Acceptance rates   │        │   • Size classification │      │
│      └────────────────────────┘        └─────────────────────────┘      │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 📁 Project Structure

```
dbt-training/
├── dbt_project.yml           # Project configuration
├── models/
│   ├── staging/
│   │   └── stackoverflow/
│   │       ├── sources.yml                    # Source definitions
│   │       ├── schema.yml                     # Model tests
│   │       ├── stg_stackoverflow__questions.sql
│   │       ├── stg_stackoverflow__users.sql
│   │       └── stg_stackoverflow__tags.sql
│   └── marts/
│       └── analytics/
│           ├── schema.yml                     # Model tests
│           ├── fct_questions_summary.sql
│           └── dim_tags.sql
├── learning_resources/       # Training documentation
├── seeds/                    # CSV seed files (empty)
├── macros/                   # Custom Jinja macros
├── snapshots/                # SCD Type 2 snapshots
└── tests/                    # Custom tests
```

---

## 📊 Source Tables (BigQuery Public Data)

### Source: `bigquery-public-data.stackoverflow`

| Table | Description | Size |
|-------|-------------|------|
| `posts_questions` | All Stack Overflow questions | ~24M rows |
| `posts_answers` | All answers to questions | ~35M rows |
| `users` | Stack Overflow user profiles | ~21M rows |
| `tags` | All tags with usage counts | ~64K rows |

---

## 🔄 Staging Models

### `stg_stackoverflow__questions`
**Location:** `saras-bigquery.dbt_training_staging.stg_stackoverflow__questions`

Filtered to data engineering related questions (Python, SQL, BigQuery, dbt, Spark, etc.) from the last 2 years.

| Column | Type | Description |
|--------|------|-------------|
| `question_id` | INT64 | Primary key |
| `title` | STRING | Question title |
| `tags` | STRING | Pipe-separated tags |
| `created_at` | TIMESTAMP | When question was asked |
| `score` | INT64 | Net upvotes/downvotes |
| `view_count` | INT64 | Number of views |
| `answer_count` | INT64 | Number of answers |
| `accepted_answer_id` | INT64 | ID of accepted answer |
| `asked_by_user_id` | INT64 | User who asked |
| `has_accepted_answer` | BOOL | Has accepted answer? |
| `score_category` | STRING | high/medium/neutral/negative |

**Partitioned by:** `created_at` (monthly)

---

### `stg_stackoverflow__users`
**Location:** `saras-bigquery.dbt_training_staging.stg_stackoverflow__users`

Active users with reputation >= 100.

| Column | Type | Description |
|--------|------|-------------|
| `user_id` | INT64 | Primary key |
| `display_name` | STRING | User's display name |
| `reputation` | INT64 | Reputation score |
| `joined_at` | TIMESTAMP | Account creation date |
| `location` | STRING | User's location |
| `user_tier` | STRING | legendary/expert/established/active/newcomer |

**Sample Data:**
| user_id | display_name | reputation | location | user_tier |
|---------|--------------|------------|----------|-----------|
| 1826 | Graham | 14,615 | Scotland | expert |
| 5790 | Alex Duggleby | 7,868 | Vienna, Austria | established |
| 17017 | Peter Rowell | 17,405 | Sebastopol, CA | expert |
| 23020 | albertein | 25,626 | Mexico | expert |

**Row Count:** ~1.2 million users

---

### `stg_stackoverflow__tags`
**Location:** `saras-bigquery.dbt_training_staging.stg_stackoverflow__tags`

Data engineering related tags only.

| Column | Type | Description |
|--------|------|-------------|
| `tag_id` | INT64 | Primary key |
| `tag_name` | STRING | Tag name |
| `question_count` | INT64 | Number of questions with this tag |
| `tag_category` | STRING | programming/database/data_tools/cloud/devops/data_formats/architecture |

**Sample Data:**
| tag_id | tag_name | question_count | tag_category |
|--------|----------|----------------|--------------|
| 22 | sql | 643,145 | programming |
| 1508 | json | 346,406 | data_formats |
| 67719 | pandas | 259,731 | programming |
| 98880 | apache-spark | 77,131 | data_tools |
| 119 | git | 144,157 | devops |

**Row Count:** 29 tags

---

## 📈 Mart Models

### `dim_tags`
**Location:** `saras-bigquery.dbt_training_analytics.dim_tags`

Enriched tag dimension with rankings and classifications.

| Column | Type | Description |
|--------|------|-------------|
| `tag_id` | INT64 | Primary key |
| `tag_name` | STRING | Tag name |
| `question_count` | INT64 | Total questions |
| `tag_category` | STRING | Category grouping |
| `popularity_rank` | INT64 | Overall popularity (1 = most popular) |
| `category_rank` | INT64 | Rank within category |
| `tag_size` | STRING | mega/large/medium/small/micro |

**Sample Data (Top 10 Most Popular):**
| rank | tag_name | question_count | tag_category | tag_size |
|------|----------|----------------|--------------|----------|
| 1 | python | 2,026,741 | programming | mega |
| 2 | mysql | 651,413 | database | large |
| 3 | sql | 643,145 | programming | large |
| 4 | json | 346,406 | data_formats | large |
| 5 | pandas | 259,731 | programming | large |
| 6 | mongodb | 166,640 | database | large |
| 7 | postgresql | 159,996 | database | large |
| 8 | git | 144,157 | devops | large |
| 9 | azure | 123,370 | cloud | large |
| 10 | docker | 120,499 | devops | large |

---

### `fct_questions_summary`
**Location:** `saras-bigquery.dbt_training_analytics.fct_questions_summary`

Daily aggregated metrics for questions.

| Column | Type | Description |
|--------|------|-------------|
| `question_date` | DATE | Primary key |
| `total_questions` | INT64 | Questions asked that day |
| `questions_with_accepted_answer` | INT64 | Accepted answer count |
| `acceptance_rate_pct` | FLOAT64 | % with accepted answers |
| `avg_score` | FLOAT64 | Average question score |
| `total_views` | INT64 | Sum of views |
| `avg_answers_per_question` | FLOAT64 | Avg answers per question |
| `high_score_questions` | INT64 | Score >= 10 |
| `medium_score_questions` | INT64 | Score 1-9 |
| `neutral_score_questions` | INT64 | Score = 0 |
| `negative_score_questions` | INT64 | Score < 0 |

---

## ✅ Data Quality Tests

All models have schema tests defined:

| Model | Tests |
|-------|-------|
| `stg_stackoverflow__questions` | unique(question_id), not_null(question_id, title, created_at) |
| `stg_stackoverflow__users` | unique(user_id), not_null(user_id, reputation) |
| `stg_stackoverflow__tags` | unique(tag_id, tag_name), not_null(tag_id, tag_name) |
| `dim_tags` | unique(tag_id, tag_name), not_null(tag_id, tag_name) |
| `fct_questions_summary` | unique(question_date), not_null(question_date) |

**Test Results:** 17/17 passing ✅

---

## 🔧 dbt Commands

```powershell
# Activate environment
conda activate dbt-env

# Run all models
dbt run

# Run staging only
dbt run --select staging

# Run marts only  
dbt run --select marts

# Run tests
dbt test

# Preview data
dbt show --select dim_tags --limit 20

# Generate docs
dbt docs generate
dbt docs serve --port 8081
```

---

## 🌐 View in BigQuery Console

1. Go to: https://console.cloud.google.com/bigquery
2. Project: `saras-bigquery`
3. Datasets:
   - `dbt_training` - Default dataset
   - `dbt_training_staging` - Staging tables
   - `dbt_training_analytics` - Analytics marts

### Quick Queries:

```sql
-- Top 10 data engineering tags by popularity
SELECT tag_name, question_count, tag_category, popularity_rank
FROM `saras-bigquery.dbt_training_analytics.dim_tags`
ORDER BY popularity_rank
LIMIT 10;

-- Top users by reputation
SELECT display_name, reputation, user_tier, location
FROM `saras-bigquery.dbt_training_staging.stg_stackoverflow__users`
ORDER BY reputation DESC
LIMIT 20;

-- Tag distribution by category
SELECT tag_category, COUNT(*) as tag_count, SUM(question_count) as total_questions
FROM `saras-bigquery.dbt_training_analytics.dim_tags`
GROUP BY tag_category
ORDER BY total_questions DESC;
```

---

## 📚 Learning Resources

See the `learning_resources/` folder for:
- BigQuery fundamentals
- dbt concepts and best practices
- Hands-on exercises
- Command cheatsheets

Start with: [learning_resources/00_START_HERE.md](learning_resources/00_START_HERE.md)
