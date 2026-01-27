-- Staging model for Stack Overflow tags
-- Source: bigquery-public-data.stackoverflow.tags

{{ config(
    materialized='table'
) }}

WITH source AS (
    SELECT *
    FROM {{ source('stackoverflow', 'tags') }}
    WHERE 
        -- Filter for data engineering related tags
        tag_name IN (
            'python',
            'sql',
            'bigquery',
            'dbt',
            'apache-spark',
            'pyspark',
            'etl',
            'data-pipeline',
            'airflow',
            'apache-airflow',
            'pandas',
            'numpy',
            'data-engineering',
            'google-cloud-platform',
            'aws',
            'azure',
            'snowflake-cloud-data-platform',
            'databricks',
            'kafka',
            'postgresql',
            'mysql',
            'mongodb',
            'redis',
            'docker',
            'kubernetes',
            'terraform',
            'git',
            'json',
            'csv',
            'parquet',
            'data-warehouse',
            'data-lake',
            'data-modeling'
        )
),

renamed AS (
    SELECT
        id AS tag_id,
        tag_name,
        count AS question_count,
        
        -- Categorize tags
        CASE 
            WHEN tag_name IN ('python', 'sql', 'pandas', 'numpy', 'pyspark') THEN 'programming'
            WHEN tag_name IN ('bigquery', 'snowflake-cloud-data-platform', 'postgresql', 'mysql', 'mongodb', 'redis') THEN 'database'
            WHEN tag_name IN ('apache-spark', 'airflow', 'apache-airflow', 'kafka', 'dbt', 'etl', 'data-pipeline') THEN 'data_tools'
            WHEN tag_name IN ('google-cloud-platform', 'aws', 'azure', 'databricks') THEN 'cloud'
            WHEN tag_name IN ('docker', 'kubernetes', 'terraform', 'git') THEN 'devops'
            WHEN tag_name IN ('json', 'csv', 'parquet') THEN 'data_formats'
            WHEN tag_name IN ('data-warehouse', 'data-lake', 'data-modeling', 'data-engineering') THEN 'architecture'
            ELSE 'other'
        END AS tag_category
        
    FROM source
)

SELECT * FROM renamed
