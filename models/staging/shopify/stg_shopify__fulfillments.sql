-- =============================================================================
-- STAGING MODEL: stg_shopify__fulfillments
-- =============================================================================
-- PURPOSE: Flatten nested fulfillments array from orders into a separate table
-- 
-- WHAT IS A FULFILLMENT?
--   A fulfillment represents a SHIPMENT for an order
--   One order can have multiple fulfillments (split shipments)
--   Each fulfillment has tracking info and shipped items
--
-- WHY A SEPARATE TABLE?
--   1. Track shipping status independently from orders
--   2. Handle partial fulfillments (some items shipped, some pending)
--   3. Enable shipping carrier analysis
--   4. Track delivery performance metrics
--
-- RELATIONSHIP: orders (1) ←→ (many) fulfillments
--   Join key: order_id
-- =============================================================================

{{ config(
    materialized='view',
    description='Flattened fulfillments from Shopify orders - shipping and tracking data'
) }}

WITH source AS (
    SELECT * FROM {{ source('shopify_raw', 'orders') }}
),

-- =============================================================================
-- FILTER ORDERS THAT HAVE FULFILLMENTS
-- =============================================================================
-- Not all orders have fulfillments (pending orders won't)
-- ARRAY_LENGTH checks if the array has elements

orders_with_fulfillments AS (
    SELECT *
    FROM source
    WHERE fulfillments IS NOT NULL 
      AND ARRAY_LENGTH(fulfillments) > 0
),

-- =============================================================================
-- UNNEST THE FULFILLMENTS ARRAY
-- =============================================================================
unnested AS (
    SELECT
        -- Keep order-level identifiers for joining
        CAST(source.id AS STRING) AS order_id,
        source.order_number,
        source.name AS order_name,
        CAST(source.created_at AS TIMESTAMP) AS order_created_at,
        
        -- Unnest the fulfillments array
        fulfillment
        
    FROM orders_with_fulfillments AS source,
    UNNEST(fulfillments) AS fulfillment
),

-- =============================================================================
-- EXTRACT AND RENAME FIELDS FROM THE STRUCT
-- =============================================================================
renamed AS (
    SELECT
        -- Primary key
        CAST(fulfillment.id AS STRING) AS fulfillment_id,
        
        -- Foreign key to orders
        order_id,
        order_number,
        order_name,
        order_created_at,
        
        -- Fulfillment name/reference
        fulfillment.name AS fulfillment_name,           -- e.g., "#JC730928.1"
        
        -- Timestamps
        CAST(fulfillment.created_at AS TIMESTAMP) AS fulfilled_at,
        CAST(fulfillment.updated_at AS TIMESTAMP) AS fulfillment_updated_at,
        
        -- Shipping carrier info
        fulfillment.tracking_company AS shipping_carrier,
        fulfillment.tracking_number,
        fulfillment.tracking_url,
        
        -- Handle multiple tracking numbers (stored as string, might be comma-separated)
        fulfillment.tracking_numbers AS tracking_numbers_raw,
        fulfillment.tracking_urls AS tracking_urls_raw,
        
        -- Fulfillment status
        LOWER(fulfillment.status) AS fulfillment_status,        -- success, pending, cancelled
        LOWER(fulfillment.shipment_status) AS shipment_status,  -- confirmed, in_transit, delivered
        
        -- Service type
        fulfillment.service AS fulfillment_service,
        
        -- Location
        CAST(fulfillment.location_id AS STRING) AS fulfillment_location_id,
        
        -- Admin reference
        fulfillment.admin_graphql_api_id

    FROM unnested
),

-- =============================================================================
-- DEDUPLICATE - KEEP ONLY ONE ROW PER FULFILLMENT
-- =============================================================================
-- Multiple sync batches may create duplicate rows; keep the latest.

deduplicated AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY fulfillment_id
            ORDER BY fulfillment_updated_at DESC
        ) AS _dedup_row_num
    FROM renamed
),

filtered AS (
    SELECT * EXCEPT(_dedup_row_num)
    FROM deduplicated
    WHERE _dedup_row_num = 1
),

-- =============================================================================
-- ADD CALCULATED FIELDS AND WINDOW FUNCTIONS
-- =============================================================================
with_analytics AS (
    SELECT
        *,
        
        -- Calculate time from order to fulfillment
        TIMESTAMP_DIFF(fulfilled_at, order_created_at, HOUR) AS hours_to_fulfill,
        TIMESTAMP_DIFF(fulfilled_at, order_created_at, DAY) AS days_to_fulfill,
        
        -- Fulfillment sequence (for split shipments)
        ROW_NUMBER() OVER (
            PARTITION BY order_id 
            ORDER BY fulfilled_at
        ) AS fulfillment_sequence,
        
        -- Total fulfillments for this order
        COUNT(*) OVER (
            PARTITION BY order_id
        ) AS order_fulfillment_count,
        
        -- Is this a split shipment order?
        CASE 
            WHEN COUNT(*) OVER (PARTITION BY order_id) > 1 
            THEN TRUE 
            ELSE FALSE 
        END AS is_split_shipment,
        
        -- Carrier standardization (group similar carriers)
        CASE
            WHEN LOWER(shipping_carrier) LIKE '%fedex%' THEN 'FedEx'
            WHEN LOWER(shipping_carrier) LIKE '%ups%' THEN 'UPS'
            WHEN LOWER(shipping_carrier) LIKE '%usps%' THEN 'USPS'
            WHEN LOWER(shipping_carrier) LIKE '%dhl%' THEN 'DHL'
            ELSE COALESCE(shipping_carrier, 'Unknown')
        END AS shipping_carrier_standardized,
        
        -- Delivery status flags
        CASE 
            WHEN shipment_status = 'delivered' THEN TRUE 
            ELSE FALSE 
        END AS is_delivered,
        
        CASE 
            WHEN shipment_status = 'in_transit' THEN TRUE 
            ELSE FALSE 
        END AS is_in_transit

    FROM filtered
)

SELECT * FROM with_analytics
