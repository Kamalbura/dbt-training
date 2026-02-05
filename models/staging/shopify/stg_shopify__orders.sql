-- =============================================================================
-- STAGING MODEL: stg_shopify__orders
-- =============================================================================
-- PURPOSE: Clean and standardize raw Shopify order data
-- 
-- KEY TRANSFORMATIONS:
--   1. Rename columns to consistent naming convention
--   2. Cast data types appropriately
--   3. Add window functions for analytics
--   4. EXCLUDE nested columns (handled by separate models)
--
-- WINDOW FUNCTIONS USED:
--   - ROW_NUMBER(): Identify order sequence per customer
--   - LAG(): Get previous order date for retention analysis
--   - SUM() OVER(): Running total of customer spend
--   - COUNT() OVER(): Total orders per customer (for segmentation)
-- =============================================================================

{{ config(
    materialized='view',
    description='Cleaned Shopify orders with customer-level window metrics'
) }}

WITH source AS (
    -- Pull from raw BigQuery table
    SELECT * FROM {{ source('shopify_raw', 'orders') }}
),

-- =============================================================================
-- STEP 1: EXTRACT CUSTOMER ID FROM NESTED ARRAY
-- =============================================================================
-- The customer field is an array with one element, we need to extract it
extract_customer AS (
    SELECT
        *,
        -- Safely extract customer_id from nested array
        -- customer[OFFSET(0)].id means: first element of customer array, then get id
        CAST(customer[SAFE_OFFSET(0)].id AS STRING) AS customer_id_extracted
    FROM source
),

-- =============================================================================
-- STEP 2: CLEAN AND RENAME COLUMNS
-- =============================================================================
renamed AS (
    SELECT
        -- Primary Keys
        CAST(id AS STRING) AS order_id,
        customer_id_extracted AS customer_id,
        
        -- Order identifiers
        name AS order_name,                              -- e.g., "#JC730928"
        CAST(order_number AS INT64) AS order_number,
        confirmation_number,
        
        -- Timestamps (cast to proper TIMESTAMP type)
        CAST(created_at AS TIMESTAMP) AS order_created_at,
        CAST(processed_at AS TIMESTAMP) AS order_processed_at,
        CAST(updated_at AS TIMESTAMP) AS order_updated_at,
        CAST(closed_at AS TIMESTAMP) AS order_closed_at,
        CAST(cancelled_at AS TIMESTAMP) AS order_cancelled_at,
        
        -- Financial data (cast to numeric for calculations)
        CAST(subtotal_price AS FLOAT64) AS subtotal_amount,
        CAST(total_discounts AS FLOAT64) AS discount_amount,
        CAST(total_tax AS FLOAT64) AS tax_amount,
        CAST(total_price AS FLOAT64) AS total_amount,
        CAST(total_line_items_price AS FLOAT64) AS line_items_total,
        CAST(total_tip_received AS FLOAT64) AS tip_amount,
        
        -- Currency info
        currency AS order_currency,
        presentment_currency,
        
        -- Status fields (standardize to lowercase)
        LOWER(financial_status) AS payment_status,
        LOWER(COALESCE(fulfillment_status, 'unfulfilled')) AS fulfillment_status,
        LOWER(cancel_reason) AS cancellation_reason,
        
        -- Source/channel tracking
        source_name AS order_source,                     -- "TikTok", "web"
        source_identifier,
        COALESCE(referring_site, 'direct') AS referring_site,
        
        -- Customer contact
        email AS customer_email,
        phone AS customer_phone,
        
        -- Flags (cast string booleans to actual booleans)
        CAST(confirmed AS BOOL) AS is_confirmed,
        CAST(test AS BOOL) AS is_test_order,
        CAST(taxes_included AS BOOL) AS is_tax_inclusive,
        CAST(buyer_accepts_marketing AS BOOL) AS accepts_marketing,
        
        -- Tags for filtering
        tags AS order_tags,
        
        -- Metadata
        CAST(app_id AS STRING) AS app_id,
        token AS order_token,
        
        -- Data sync fields (from Daton)
        _daton_user_id,
        TIMESTAMP_MILLIS(CAST(_daton_batch_runtime AS INT64)) AS synced_at,
        _daton_batch_id
        
        -- NOTE: Nested columns EXCLUDED here - they get their own models:
        -- line_items → stg_shopify__order_line_items
        -- fulfillments → stg_shopify__fulfillments
        -- customer → fields extracted above
        -- shipping_address, discount_codes, etc.

    FROM extract_customer
),

-- =============================================================================
-- STEP 2.5: DEDUPLICATE - KEEP ONLY LATEST SYNC PER ORDER
-- =============================================================================
-- The source may have duplicate records from multiple sync batches.
-- We keep only the most recent version of each order.

deduplicated AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY order_id
            ORDER BY synced_at DESC
        ) AS _dedup_row_num
    FROM renamed
),

filtered AS (
    SELECT * EXCEPT(_dedup_row_num)
    FROM deduplicated
    WHERE _dedup_row_num = 1
),

-- =============================================================================
-- STEP 3: ADD WINDOW FUNCTIONS FOR ANALYTICS
-- =============================================================================
-- Window functions calculate values across related rows WITHOUT collapsing them
-- They're like GROUP BY but keep all the detail rows

with_window_functions AS (
    SELECT
        *,
        
        -- WINDOW FUNCTION 1: Customer Order Sequence
        -- What order number is this for this customer? (1st, 2nd, 3rd...)
        ROW_NUMBER() OVER (
            PARTITION BY customer_id 
            ORDER BY order_created_at
        ) AS customer_order_sequence,
        
        -- WINDOW FUNCTION 2: Previous Order Date (for retention analysis)
        -- When did this customer last order? (NULL for first order)
        LAG(order_created_at) OVER (
            PARTITION BY customer_id 
            ORDER BY order_created_at
        ) AS previous_order_at,
        
        -- WINDOW FUNCTION 3: Days Since Previous Order
        -- How many days between orders?
        DATE_DIFF(
            DATE(order_created_at),
            DATE(LAG(order_created_at) OVER (
                PARTITION BY customer_id 
                ORDER BY order_created_at
            )),
            DAY
        ) AS days_since_previous_order,
        
        -- WINDOW FUNCTION 4: Running Total of Customer Spend
        -- Cumulative amount this customer has spent
        SUM(total_amount) OVER (
            PARTITION BY customer_id 
            ORDER BY order_created_at
            ROWS UNBOUNDED PRECEDING
        ) AS customer_running_total,
        
        -- WINDOW FUNCTION 5: Total Orders by Customer (for segmentation)
        -- How many orders has this customer placed in total?
        COUNT(*) OVER (
            PARTITION BY customer_id
        ) AS customer_total_orders,
        
        -- WINDOW FUNCTION 6: Total Lifetime Value by Customer
        -- What's the customer's total spend across all orders?
        SUM(total_amount) OVER (
            PARTITION BY customer_id
        ) AS customer_lifetime_value,
        
        -- WINDOW FUNCTION 7: Is First Order Flag
        -- Useful for new customer analysis
        CASE 
            WHEN ROW_NUMBER() OVER (
                PARTITION BY customer_id 
                ORDER BY order_created_at
            ) = 1 THEN TRUE 
            ELSE FALSE 
        END AS is_first_order,
        
        -- WINDOW FUNCTION 8: Daily Order Rank
        -- Within each day, what's the order sequence?
        ROW_NUMBER() OVER (
            PARTITION BY DATE(order_created_at)
            ORDER BY order_created_at
        ) AS daily_order_sequence

    FROM filtered
    -- Exclude test orders from analytics — use the renamed boolean column
    WHERE COALESCE(is_test_order, FALSE) = FALSE
)

SELECT * FROM with_window_functions
