-- Staging model for orders
-- Source: raw_orders seed file
-- This model cleans and renames the raw order data

{{ config(materialized='view') }}

WITH source AS (
    SELECT * FROM {{ ref('raw_orders') }}
),

renamed AS (
    SELECT
        id AS order_id,
        user_id AS customer_id,
        order_date,
        status AS order_status

    FROM source
)

SELECT * FROM renamed
