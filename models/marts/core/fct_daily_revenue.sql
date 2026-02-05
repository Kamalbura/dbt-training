-- =============================================================================
-- FACT TABLE: fct_daily_revenue
-- =============================================================================
-- PURPOSE: Daily aggregated revenue metrics for dashboards
--
-- GRAIN: One row per day
--
-- Use this for:
-- - Executive dashboards
-- - Trend analysis
-- - Day-over-day comparisons
-- =============================================================================

{{ config(
    materialized='table',
    description='Daily revenue summary for dashboards',
    tags=['core', 'daily']
) }}

WITH orders AS (
    SELECT * FROM {{ ref('fct_orders') }}
    WHERE is_canceled = FALSE  -- Exclude canceled orders
),

daily_aggregation AS (
    SELECT
        -- =================================================================
        -- DATE GRAIN
        -- =================================================================
        order_date,
        order_year,
        order_month,
        
        -- =================================================================
        -- ORDER COUNTS
        -- =================================================================
        COUNT(*) AS order_count,
        COUNTIF(is_first_order) AS new_customer_orders,
        COUNT(*) - COUNTIF(is_first_order) AS returning_customer_orders,
        
        -- =================================================================
        -- REVENUE METRICS
        -- =================================================================
        SUM(total_amount) AS total_revenue,
        SUM(subtotal_amount) AS gross_revenue,
        SUM(discount_amount) AS total_discounts,
        SUM(tax_amount) AS total_tax,
        SUM(tip_amount) AS total_tips,
        
        -- =================================================================
        -- AVERAGES
        -- =================================================================
        AVG(total_amount) AS average_order_value,
        AVG(line_item_count) AS avg_items_per_order,
        AVG(total_quantity) AS avg_units_per_order,
        
        -- =================================================================
        -- FULFILLMENT METRICS
        -- =================================================================
        AVG(hours_to_first_fulfillment) AS avg_hours_to_fulfill,
        
        -- =================================================================
        -- CUSTOMER METRICS
        -- =================================================================
        COUNT(DISTINCT customer_id) AS unique_customers

    FROM orders
    GROUP BY order_date, order_year, order_month
)

SELECT 
    *,
    
    -- =================================================================
    -- DERIVED METRICS
    -- =================================================================
    SAFE_DIVIDE(total_revenue, unique_customers) AS revenue_per_customer,
    SAFE_DIVIDE(new_customer_orders, order_count) AS new_customer_rate,
    SAFE_DIVIDE(total_discounts, gross_revenue) AS discount_rate

FROM daily_aggregation
ORDER BY order_date DESC
