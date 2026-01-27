-- Staging model for Stack Overflow questions
-- Source: bigquery-public-data.stackoverflow.posts_questions
-- This model selects data engineering related questions (filtered by tags)

{{ config(
    materialized='table',
    partition_by={
        "field": "created_at",
        "data_type": "timestamp",
        "granularity": "month"
    }
) }}

WITH source AS (
    SELECT *
    FROM {{ source('stackoverflow', 'posts_questions') }}
    WHERE 
        -- Filter for data engineering related tags
        (
            tags LIKE '%python%'
            OR tags LIKE '%sql%'
            OR tags LIKE '%bigquery%'
            OR tags LIKE '%dbt%'
            OR tags LIKE '%apache-spark%'
            OR tags LIKE '%etl%'
            OR tags LIKE '%data-pipeline%'
            OR tags LIKE '%airflow%'
        )
        -- Limit to recent questions (last 2 years) to manage costs
        AND creation_date >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 730 DAY)
        -- Only questions with at least 1 answer
        AND answer_count > 0
),

renamed AS (
    SELECT
        id AS question_id,
        title,
        tags,
        creation_date AS created_at,
        score,
        view_count,
        answer_count,
        accepted_answer_id,
        owner_user_id AS asked_by_user_id,
        
        -- Derived fields
        CASE WHEN accepted_answer_id IS NOT NULL THEN TRUE ELSE FALSE END AS has_accepted_answer,
        CASE 
            WHEN score >= 10 THEN 'high'
            WHEN score >= 1 THEN 'medium'
            WHEN score = 0 THEN 'neutral'
            ELSE 'negative'
        END AS score_category
        
    FROM source
)

SELECT * FROM renamed
