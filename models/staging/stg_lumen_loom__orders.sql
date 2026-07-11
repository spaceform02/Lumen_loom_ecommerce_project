WITH orders AS (
    SELECT *
    FROM {{source('lumen_loom', 'raw_orders')}}
)

SELECT 
    {{dbt_utils.generate_surrogate_key(['order_id', 'customer_id'])}} AS order_key,
    order_id,
    customer_id,
    TRIM(order_status) AS order_status,
    order_amount,
    TRIM(currency) AS currency,
    CAST(created_at AS timestamp_ntz(0)) AS created_at,
    CAST(updated_at AS timestamp_ntz(0)) AS updated_at
FROM orders

