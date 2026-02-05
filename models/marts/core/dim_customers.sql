-- =============================================================================
-- DIMENSION TABLE: dim_customers
-- =============================================================================
-- PURPOSE: Customer dimension with lifetime metrics and segmentation
--
-- GRAIN: One row per customer
--
-- Includes:
-- - Contact information
-- - Acquisition data
-- - RFM segmentation
-- - Customer tiers
-- =============================================================================

{{ config(
    materialized='table',
    description='Customer dimension with RFM segmentation and lifetime metrics',
    tags=['core', 'daily']
) }}

WITH customer_history AS (
    SELECT * FROM {{ ref('int_customers__order_history') }}
),

final AS (
    SELECT
        -- =================================================================
        -- PRIMARY KEY
        -- =================================================================
        customer_id,
        
        -- =================================================================
        -- CONTACT INFO
        -- =================================================================
        customer_email,
        
        -- =================================================================
        -- ACQUISITION ATTRIBUTES
        -- =================================================================
        acquisition_source,
        DATE(first_order_at) AS first_order_date,
        
        -- =================================================================
        -- RECENCY ATTRIBUTES
        -- =================================================================
        DATE(most_recent_order_at) AS most_recent_order_date,
        days_since_last_order,
        days_as_customer,
        
        -- =================================================================
        -- FREQUENCY ATTRIBUTES
        -- =================================================================
        total_orders AS lifetime_order_count,
        avg_days_between_orders,
        
        -- =================================================================
        -- MONETARY ATTRIBUTES
        -- =================================================================
        lifetime_revenue AS lifetime_value,
        average_order_value,
        min_order_value,
        max_order_value,
        total_discounts_used,
        discount_usage_rate,
        
        -- =================================================================
        -- BEHAVIOR FLAGS
        -- =================================================================
        CASE WHEN orders_with_marketing_consent > 0 
             THEN TRUE ELSE FALSE 
        END AS has_marketing_consent,
        
        -- =================================================================
        -- RFM SEGMENTATION
        -- =================================================================
        frequency_segment,
        recency_segment,
        value_segment,
        
        -- Combined RFM segment
        CONCAT(recency_segment, '_', frequency_segment, '_', value_segment) AS rfm_segment,
        
        -- =================================================================
        -- CUSTOMER TIER
        -- =================================================================
        CASE
            WHEN value_segment = 'vip' THEN 'platinum'
            WHEN value_segment = 'high_value' AND frequency_segment IN ('loyal', 'champion') THEN 'gold'
            WHEN value_segment IN ('high_value', 'medium_value') THEN 'silver'
            ELSE 'bronze'
        END AS customer_tier,
        
        -- =================================================================
        -- CHURN RISK
        -- =================================================================
        CASE
            WHEN recency_segment = 'churned' THEN TRUE
            WHEN recency_segment = 'at_risk' AND value_segment IN ('high_value', 'vip') THEN TRUE
            ELSE FALSE
        END AS is_at_churn_risk,
        
        -- =================================================================
        -- METADATA
        -- =================================================================
        CURRENT_TIMESTAMP() AS updated_at

    FROM customer_history
)

SELECT * FROM final
