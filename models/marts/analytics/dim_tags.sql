-- Dimension table: Tags with enrichments
-- This provides tag information for analysis

{{ config(
    materialized='table'
) }}

WITH tags AS (
    SELECT * FROM {{ ref('stg_stackoverflow__tags') }}
),

enriched AS (
    SELECT
        tag_id,
        tag_name,
        question_count,
        tag_category,
        
        -- Popularity ranking
        RANK() OVER (ORDER BY question_count DESC) AS popularity_rank,
        RANK() OVER (PARTITION BY tag_category ORDER BY question_count DESC) AS category_rank,
        
        -- Size classification
        CASE 
            WHEN question_count >= 1000000 THEN 'mega'
            WHEN question_count >= 100000 THEN 'large'
            WHEN question_count >= 10000 THEN 'medium'
            WHEN question_count >= 1000 THEN 'small'
            ELSE 'micro'
        END AS tag_size
        
    FROM tags
)

SELECT * FROM enriched
ORDER BY popularity_rank
