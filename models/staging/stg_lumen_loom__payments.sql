WITH payments AS (
    SELECT *
    FROM {{source('lumen_loom', 'raw_payments')}}
)

SELECT 
    {{dbt_utils.generate_surrogate_key(['payment_id', 'order_id'])}} AS payment_key,
    payment_id,
    order_id,
    TRIM(payment_status) AS payment_status,
    amount,
    TRIM(currency) AS currency,
    TRIM(payment_method) AS payment_method,
    gateway_fee,
    CAST(attempted_at AS timestamp_ntz(0)) AS attempted_at,
    CAST(processed_at AS timestamp_ntz(0)) AS processed_at
FROM payments

