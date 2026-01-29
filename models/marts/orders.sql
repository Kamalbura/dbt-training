-- Orders mart
-- This model creates an order-level summary with payment totals

{{ config(materialized='table') }}

WITH orders AS (
    SELECT * FROM {{ ref('stg_orders') }}
),

payments AS (
    SELECT * FROM {{ ref('stg_payments') }}
),

order_payments AS (
    SELECT
        order_id,
        SUM(amount) AS total_amount,
        COUNT(*) AS payment_count

    FROM payments
    GROUP BY order_id
),

final AS (
    SELECT
        orders.order_id,
        orders.customer_id,
        orders.order_date,
        orders.order_status,
        COALESCE(order_payments.total_amount, 0) AS amount,
        COALESCE(order_payments.payment_count, 0) AS payment_count

    FROM orders
    LEFT JOIN order_payments ON orders.order_id = order_payments.order_id
)

SELECT * FROM final
