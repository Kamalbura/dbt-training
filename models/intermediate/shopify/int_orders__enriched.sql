-- =============================================================================
-- INTERMEDIATE MODEL: int_orders__enriched
-- =============================================================================
-- PURPOSE: Combine order data with line item and fulfillment summaries
-- 
-- This model:
--   1. Starts with deduplicated orders
--   2. Aggregates line items to order level
--   3. Aggregates fulfillments to order level
--   4. Calculates derived metrics
--
-- GRAIN: One row per order
-- =============================================================================

{{ config(
    materialized='view',
    description='Orders enriched with line item aggregates and fulfillment metrics'
) }}

WITH orders AS (
    -- Get cleaned orders from staging
    SELECT * FROM {{ ref('stg_shopify__orders') }}
),

-- Aggregate line items to order level
line_item_summary AS (
    SELECT
        order_id,
        COUNT(*) AS line_item_count,
        SUM(quantity) AS total_quantity,
        SUM(line_total_before_discount) AS line_items_total
    FROM {{ ref('stg_shopify__order_line_items') }}
    GROUP BY order_id
),

-- Aggregate fulfillments to order level
fulfillment_summary AS (
    SELECT
        order_id,
        MIN(fulfilled_at) AS first_fulfilled_at,
        MAX(fulfilled_at) AS last_fulfilled_at,
        COUNT(*) AS fulfillment_count,
        LOGICAL_OR(is_delivered) AS has_delivered_fulfillment
    FROM {{ ref('stg_shopify__fulfillments') }}
    GROUP BY order_id
),

enriched AS (
    SELECT
        -- Order fields
        o.order_id,
        o.customer_id,
        o.order_name,
        o.order_number,
        o.order_created_at,
        o.order_processed_at,
        
        -- Financial metrics
        o.subtotal_amount,
        o.discount_amount,
        o.tax_amount,
        o.total_amount,
        o.tip_amount,
        
        -- Statuses
        o.payment_status,
        o.fulfillment_status,
        o.cancellation_reason,
        
        -- Source tracking
        o.order_source,
        o.referring_site,
        
        -- Customer flags from staging window functions
        o.accepts_marketing,
        o.is_first_order,
        o.customer_order_sequence,
        o.customer_lifetime_value,
        o.customer_total_orders,
        
        -- Line item metrics (from aggregation)
        COALESCE(lis.line_item_count, 0) AS line_item_count,
        COALESCE(lis.total_quantity, 0) AS total_quantity,
        COALESCE(lis.line_items_total, 0) AS line_items_total,
        
        -- Fulfillment metrics (from aggregation)
        fs.first_fulfilled_at,
        fs.last_fulfilled_at,
        COALESCE(fs.fulfillment_count, 0) AS fulfillment_count,
        COALESCE(fs.has_delivered_fulfillment, FALSE) AS is_fully_delivered,
        
        -- Calculated: Time to first fulfillment
        TIMESTAMP_DIFF(
            fs.first_fulfilled_at, 
            o.order_created_at, 
            HOUR
        ) AS hours_to_first_fulfillment,
        
        -- Calculated: Is this canceled?
        CASE 
            WHEN o.cancellation_reason IS NOT NULL THEN TRUE 
            ELSE FALSE 
        END AS is_canceled,
        
        -- Calculated: Order size bucket
        CASE
            WHEN o.total_amount < 25 THEN 'small'
            WHEN o.total_amount < 100 THEN 'medium'
            WHEN o.total_amount < 250 THEN 'large'
            ELSE 'enterprise'
        END AS order_size_bucket,
        
        -- Calculated: Discount rate
        SAFE_DIVIDE(o.discount_amount, o.subtotal_amount) AS discount_rate

    FROM orders o
    LEFT JOIN line_item_summary lis ON o.order_id = lis.order_id
    LEFT JOIN fulfillment_summary fs ON o.order_id = fs.order_id
)

SELECT * FROM enriched
