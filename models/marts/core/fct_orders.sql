-- =============================================================================
-- FACT TABLE: fct_orders
-- =============================================================================
-- PURPOSE: Order-level fact table with key metrics for analytics
--
-- GRAIN: One row per order
--
-- This is the primary table for order analysis:
-- - Revenue tracking
-- - Order patterns
-- - Customer behavior
-- =============================================================================

{{ config(
    materialized='table',
    description='Order-level fact table with key metrics for analytics',
    tags=['core', 'daily']
) }}

WITH enriched_orders AS (
    SELECT * FROM {{ ref('int_orders__enriched') }}
),

final AS (
    SELECT
        -- =================================================================
        -- PRIMARY KEY
        -- =================================================================
        order_id,
        
        -- =================================================================
        -- FOREIGN KEYS
        -- =================================================================
        customer_id,
        DATE(order_created_at) AS order_date,
        
        -- =================================================================
        -- DATE/TIME ATTRIBUTES
        -- =================================================================
        order_created_at,
        EXTRACT(YEAR FROM order_created_at) AS order_year,
        EXTRACT(MONTH FROM order_created_at) AS order_month,
        EXTRACT(DAYOFWEEK FROM order_created_at) AS order_day_of_week,
        EXTRACT(HOUR FROM order_created_at) AS order_hour,
        
        -- =================================================================
        -- ORDER IDENTIFIERS
        -- =================================================================
        order_name,
        order_number,
        
        -- =================================================================
        -- FINANCIAL MEASURES
        -- =================================================================
        subtotal_amount,
        discount_amount,
        tax_amount,
        tip_amount,
        total_amount,
        line_items_total,
        discount_rate,
        
        -- =================================================================
        -- QUANTITY MEASURES
        -- =================================================================
        line_item_count,
        total_quantity,
        
        -- =================================================================
        -- FULFILLMENT MEASURES
        -- =================================================================
        fulfillment_count,
        hours_to_first_fulfillment,
        
        -- =================================================================
        -- STATUS DIMENSIONS
        -- =================================================================
        payment_status,
        fulfillment_status,
        is_canceled,
        is_fully_delivered,
        
        -- =================================================================
        -- CUSTOMER CONTEXT
        -- =================================================================
        is_first_order,
        customer_order_sequence,
        customer_lifetime_value,
        customer_total_orders,
        
        -- =================================================================
        -- SOURCE TRACKING
        -- =================================================================
        order_source,
        referring_site,
        
        -- =================================================================
        -- DERIVED DIMENSIONS
        -- =================================================================
        order_size_bucket,
        
        -- =================================================================
        -- FLAGS
        -- =================================================================
        accepts_marketing

    FROM enriched_orders
)

SELECT * FROM final
