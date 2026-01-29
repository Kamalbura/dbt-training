-- Staging model for customers
-- Source: raw_customers seed file
-- This model cleans and renames the raw customer data

{{ config(materialized='view') }}

WITH source AS (
    SELECT * FROM {{ ref('raw_customers') }}
),

renamed AS (
    SELECT
        id AS customer_id,
        first_name,
        last_name

    FROM source
)

SELECT * FROM renamed
