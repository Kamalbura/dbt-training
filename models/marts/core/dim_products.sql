-- =============================================================================
-- DIMENSION TABLE: dim_products
-- =============================================================================
-- PURPOSE: Product dimension with sales metrics
--
-- GRAIN: One row per product
--
-- Includes:
-- - Product attributes
-- - Sales metrics
-- - Product rankings
-- =============================================================================

{{ config(
    materialized='table',
    description='Product dimension with sales metrics and rankings',
    tags=['core', 'daily']
) }}

WITH line_items AS (
    SELECT * FROM {{ ref('stg_shopify__order_line_items') }}
),

product_metrics AS (
    SELECT
        product_id,
        
        -- Get most recent product info
        ARRAY_AGG(product_title ORDER BY order_created_at DESC LIMIT 1)[OFFSET(0)] AS product_title,
        ARRAY_AGG(product_name ORDER BY order_created_at DESC LIMIT 1)[OFFSET(0)] AS product_name,
        ARRAY_AGG(product_sku ORDER BY order_created_at DESC LIMIT 1)[OFFSET(0)] AS product_sku,
        ARRAY_AGG(product_vendor ORDER BY order_created_at DESC LIMIT 1)[OFFSET(0)] AS vendor,
        ARRAY_AGG(variant_title ORDER BY order_created_at DESC LIMIT 1)[OFFSET(0)] AS variant_title,
        
        -- Counts
        COUNT(DISTINCT order_id) AS order_count,
        COUNT(*) AS line_item_count,
        
        -- Quantities
        SUM(quantity) AS total_quantity_sold,
        AVG(quantity) AS avg_quantity_per_order,
        
        -- Revenue
        SUM(line_total_before_discount) AS total_revenue,
        SUM(line_discount_amount) AS total_discounts,
        AVG(unit_price) AS average_selling_price,
        
        -- Dates
        MIN(order_created_at) AS first_sold_at,
        MAX(order_created_at) AS last_sold_at

    FROM line_items
    WHERE product_id IS NOT NULL
    GROUP BY product_id
),

final AS (
    SELECT
        -- =================================================================
        -- PRIMARY KEY
        -- =================================================================
        product_id,
        
        -- =================================================================
        -- PRODUCT ATTRIBUTES
        -- =================================================================
        product_title,
        product_name,
        product_sku,
        vendor,
        variant_title,
        
        -- =================================================================
        -- SALES METRICS
        -- =================================================================
        order_count,
        total_quantity_sold,
        total_revenue,
        total_discounts,
        avg_quantity_per_order,
        average_selling_price,
        
        -- =================================================================
        -- CALCULATED METRICS
        -- =================================================================
        SAFE_DIVIDE(total_revenue, total_quantity_sold) AS revenue_per_unit,
        
        -- =================================================================
        -- DATE ATTRIBUTES
        -- =================================================================
        DATE(first_sold_at) AS first_sold_date,
        DATE(last_sold_at) AS last_sold_date,
        DATE_DIFF(CURRENT_DATE(), DATE(last_sold_at), DAY) AS days_since_last_sale,
        
        -- =================================================================
        -- PRODUCT RANKINGS
        -- =================================================================
        RANK() OVER (ORDER BY total_revenue DESC) AS revenue_rank,
        RANK() OVER (ORDER BY total_quantity_sold DESC) AS quantity_rank,
        
        -- =================================================================
        -- PRODUCT SEGMENTS
        -- =================================================================
        CASE
            WHEN RANK() OVER (ORDER BY total_revenue DESC) <= 10 THEN 'top_10'
            WHEN RANK() OVER (ORDER BY total_revenue DESC) <= 50 THEN 'top_50'
            WHEN RANK() OVER (ORDER BY total_revenue DESC) <= 100 THEN 'top_100'
            ELSE 'other'
        END AS product_tier,
        
        CASE
            WHEN DATE_DIFF(CURRENT_DATE(), DATE(last_sold_at), DAY) > 90 THEN 'dormant'
            WHEN DATE_DIFF(CURRENT_DATE(), DATE(first_sold_at), DAY) <= 30 THEN 'new'
            ELSE 'active'
        END AS product_status,
        
        -- =================================================================
        -- METADATA
        -- =================================================================
        CURRENT_TIMESTAMP() AS updated_at

    FROM product_metrics
)

SELECT * FROM final
