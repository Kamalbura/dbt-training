-- =============================================================================
-- STAGING MODEL: stg_shopify__order_line_items
-- =============================================================================
-- PURPOSE: Flatten nested line_items array from orders into a separate table
-- 
-- WHY A SEPARATE TABLE?
--   1. One order can have MANY line items (one-to-many relationship)
--   2. Keeps the orders table clean and normalized
--   3. Enables product-level analytics
--   4. Follows best practice: one entity per table
--
-- RELATIONSHIP: orders (1) ←→ (many) line_items
--   Join key: order_id
--
-- UNNEST EXPLAINED:
--   BigQuery stores arrays as REPEATED fields
--   UNNEST() "explodes" the array into individual rows
--   Example: Order with 3 products → 3 rows in this table
-- =============================================================================

{{ config(
    materialized='view',
    description='Flattened line items from Shopify orders - one row per product per order'
) }}

WITH source AS (
    SELECT * FROM {{ source('shopify_raw', 'orders') }}
),

-- =============================================================================
-- UNNEST THE LINE_ITEMS ARRAY
-- =============================================================================
-- This transforms:
--   | order_id | line_items: [{item1}, {item2}] |
-- Into:
--   | order_id | line_item: {item1} |
--   | order_id | line_item: {item2} |

unnested AS (
    SELECT
        -- Keep order-level identifiers for joining
        CAST(source.id AS STRING) AS order_id,
        source.order_number,
        CAST(source.created_at AS TIMESTAMP) AS order_created_at,
        
        -- Unnest the line_items array
        -- Each 'line_item' is now a single STRUCT (object)
        line_item
        
    FROM source,
    UNNEST(line_items) AS line_item           -- 👈 The magic happens here!
),

-- =============================================================================
-- EXTRACT AND RENAME FIELDS FROM THE STRUCT
-- =============================================================================
renamed AS (
    SELECT
        -- Composite primary key (order_id + line_item_id)
        order_id,
        CAST(line_item.id AS STRING) AS line_item_id,
        
        -- Order context
        order_number,
        order_created_at,
        
        -- Product identification
        CAST(line_item.product_id AS STRING) AS product_id,
        CAST(line_item.variant_id AS STRING) AS variant_id,
        line_item.sku AS product_sku,
        
        -- Product details
        line_item.title AS product_title,
        line_item.name AS product_name,              -- Includes variant info
        line_item.variant_title,
        line_item.vendor AS product_vendor,
        
        -- Quantities and pricing
        CAST(line_item.quantity AS INT64) AS quantity,
        CAST(line_item.price AS FLOAT64) AS unit_price,
        CAST(line_item.total_discount AS FLOAT64) AS line_discount_amount,
        CAST(line_item.grams AS INT64) AS weight_grams,
        
        -- Calculate line total (unit_price * quantity)
        CAST(line_item.price AS FLOAT64) * CAST(line_item.quantity AS INT64) AS line_total_before_discount,
        
        -- Fulfillment info
        line_item.fulfillment_service,
        line_item.fulfillment_status,
        CAST(line_item.fulfillable_quantity AS INT64) AS fulfillable_quantity,
        
        -- Shipping and tax flags
        CAST(line_item.requires_shipping AS BOOL) AS requires_shipping,
        CAST(line_item.taxable AS BOOL) AS is_taxable,
        CAST(line_item.gift_card AS BOOL) AS is_gift_card,
        CAST(line_item.product_exists AS BOOL) AS product_exists,
        
        -- Inventory management
        line_item.variant_inventory_management AS inventory_management,
        
        -- Admin reference
        line_item.admin_graphql_api_id

    FROM unnested
),

-- =============================================================================
-- DEDUPLICATE - KEEP ONLY ONE ROW PER LINE ITEM
-- =============================================================================
-- Multiple sync batches may create duplicate rows; keep the first occurrence.

deduplicated AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY order_id, line_item_id
            ORDER BY order_created_at DESC
        ) AS _dedup_row_num
    FROM renamed
),

filtered AS (
    SELECT * EXCEPT(_dedup_row_num)
    FROM deduplicated
    WHERE _dedup_row_num = 1
),

-- =============================================================================
-- ADD WINDOW FUNCTIONS FOR LINE ITEM ANALYTICS
-- =============================================================================
with_analytics AS (
    SELECT
        *,
        
        -- Line item sequence within order
        ROW_NUMBER() OVER (
            PARTITION BY order_id 
            ORDER BY line_item_id
        ) AS line_item_sequence,
        
        -- Total line items in this order
        COUNT(*) OVER (
            PARTITION BY order_id
        ) AS order_line_item_count,
        
        -- Total quantity in this order (sum of all line item quantities)
        SUM(quantity) OVER (
            PARTITION BY order_id
        ) AS order_total_quantity,
        
        -- This line item's share of order total
        line_total_before_discount / NULLIF(
            SUM(line_total_before_discount) OVER (PARTITION BY order_id),
            0
        ) AS line_share_of_order,
        
        -- Is this a single-item order?
        CASE 
            WHEN COUNT(*) OVER (PARTITION BY order_id) = 1 
            THEN TRUE 
            ELSE FALSE 
        END AS is_single_item_order

    FROM filtered
)

SELECT * FROM with_analytics
