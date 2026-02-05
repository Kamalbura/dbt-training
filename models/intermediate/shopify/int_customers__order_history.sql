-- =============================================================================
-- INTERMEDIATE MODEL: int_customers__order_history
-- =============================================================================
-- PURPOSE: Build customer-level aggregations from order history
--
-- This model:
--   1. Aggregates all orders by customer
--   2. Calculates lifetime metrics
--   3. Creates customer segments
--
-- GRAIN: One row per customer
-- =============================================================================

{{ config(
    materialized='view',
    description='Customer-level aggregations and segmentation from order history'
) }}

WITH orders AS (
    SELECT * FROM {{ ref('stg_shopify__orders') }}
),

customer_orders AS (
    SELECT
        customer_id,
        
        -- Order counts
        COUNT(*) AS total_orders,
        
        -- Revenue metrics
        SUM(total_amount) AS lifetime_revenue,
        AVG(total_amount) AS average_order_value,
        MIN(total_amount) AS min_order_value,
        MAX(total_amount) AS max_order_value,
        
        -- Date metrics
        MIN(order_created_at) AS first_order_at,
        MAX(order_created_at) AS most_recent_order_at,
        
        -- Behavior metrics
        COUNTIF(accepts_marketing) AS orders_with_marketing_consent,
        COUNTIF(discount_amount > 0) AS orders_with_discount,
        SUM(discount_amount) AS total_discounts_used,
        
        -- Get first order source
        ARRAY_AGG(order_source ORDER BY order_created_at LIMIT 1)[OFFSET(0)] AS acquisition_source,
        
        -- Get most recent email
        ARRAY_AGG(customer_email ORDER BY order_created_at DESC LIMIT 1)[OFFSET(0)] AS customer_email

    FROM orders
    WHERE customer_id IS NOT NULL
    GROUP BY customer_id
),

with_derived_metrics AS (
    SELECT
        *,
        
        -- Days as customer
        DATE_DIFF(CURRENT_DATE(), DATE(first_order_at), DAY) AS days_as_customer,
        
        -- Days since last order
        DATE_DIFF(CURRENT_DATE(), DATE(most_recent_order_at), DAY) AS days_since_last_order,
        
        -- Average days between orders
        SAFE_DIVIDE(
            DATE_DIFF(DATE(most_recent_order_at), DATE(first_order_at), DAY),
            GREATEST(total_orders - 1, 1)
        ) AS avg_days_between_orders,
        
        -- Discount usage rate
        SAFE_DIVIDE(orders_with_discount, total_orders) AS discount_usage_rate

    FROM customer_orders
),

with_segmentation AS (
    SELECT
        *,
        
        -- Frequency segment
        CASE
            WHEN total_orders = 1 THEN 'one_time'
            WHEN total_orders BETWEEN 2 AND 3 THEN 'developing'
            WHEN total_orders BETWEEN 4 AND 10 THEN 'loyal'
            ELSE 'champion'
        END AS frequency_segment,
        
        -- Recency segment
        CASE
            WHEN days_since_last_order <= 30 THEN 'active'
            WHEN days_since_last_order <= 90 THEN 'cooling'
            WHEN days_since_last_order <= 180 THEN 'at_risk'
            ELSE 'churned'
        END AS recency_segment,
        
        -- Value segment
        CASE
            WHEN lifetime_revenue < 100 THEN 'low_value'
            WHEN lifetime_revenue < 500 THEN 'medium_value'
            WHEN lifetime_revenue < 2000 THEN 'high_value'
            ELSE 'vip'
        END AS value_segment

    FROM with_derived_metrics
)

SELECT * FROM with_segmentation
