-- Customers mart
-- This model creates a customer-level summary with order metrics

{{ config(materialized='table') }}

WITH customers AS (
    SELECT * FROM {{ ref('stg_customers') }}
),

orders AS (
    SELECT * FROM {{ ref('stg_orders') }}
),

payments AS (
    SELECT * FROM {{ ref('stg_payments') }}
),

customer_orders AS (
    SELECT
        customer_id,
        MIN(order_date) AS first_order_date,
        MAX(order_date) AS most_recent_order_date,
        COUNT(order_id) AS number_of_orders

    FROM orders
    GROUP BY customer_id
),

customer_payments AS (
    SELECT
        orders.customer_id,
        SUM(payments.amount) AS lifetime_value

    FROM payments
    LEFT JOIN orders ON payments.order_id = orders.order_id
    GROUP BY orders.customer_id
),

final AS (
    SELECT
        customers.customer_id,
        customers.first_name,
        customers.last_name,
        customer_orders.first_order_date,
        customer_orders.most_recent_order_date,
        COALESCE(customer_orders.number_of_orders, 0) AS number_of_orders,
        COALESCE(customer_payments.lifetime_value, 0) AS lifetime_value

    FROM customers
    LEFT JOIN customer_orders ON customers.customer_id = customer_orders.customer_id
    LEFT JOIN customer_payments ON customers.customer_id = customer_payments.customer_id
)

SELECT * FROM final
