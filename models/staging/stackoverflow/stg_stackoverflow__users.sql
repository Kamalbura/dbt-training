-- Staging model for Stack Overflow users
-- Source: bigquery-public-data.stackoverflow.users

{{ config(
    materialized='table'
) }}

WITH source AS (
    SELECT *
    FROM {{ source('stackoverflow', 'users') }}
    WHERE 
        -- Only users with some activity (reputation > 0)
        reputation > 0
        -- Limit to save costs - top contributors
        AND reputation >= 100
),

renamed AS (
    SELECT
        id AS user_id,
        display_name,
        reputation,
        creation_date AS joined_at,
        location,
        
        -- Derived fields
        CASE 
            WHEN reputation >= 100000 THEN 'legendary'
            WHEN reputation >= 10000 THEN 'expert'
            WHEN reputation >= 1000 THEN 'established'
            WHEN reputation >= 100 THEN 'active'
            ELSE 'newcomer'
        END AS user_tier
        
    FROM source
)

SELECT * FROM renamed
