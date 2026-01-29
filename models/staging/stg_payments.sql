-- Staging model for payments
-- Source: raw_payments seed file
-- This model cleans and renames the raw payment data

{{ config(materialized='view') }}

WITH source AS (
    SELECT * FROM {{ ref('raw_payments') }}
),

renamed AS (
    SELECT
        id AS payment_id,
        order_id,
        payment_method,
        -- Convert cents to dollars
        CAST(amount / 100.0 AS NUMERIC) AS amount

    FROM source
)

SELECT * FROM renamed
