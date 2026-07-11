WITH refunds AS (
    SELECT *
    FROM {{source('lumen_loom', 'raw_refunds')}}
)

SELECT 
    {{dbt_utils.generate_surrogate_key(['refund_id', 'order_id', 'payment_id'])}} AS refund_key,
    refund_id,
    payment_id,
    order_id,
    refund_amount,
    TRIM(currency) AS currency,
    TRIM(refund_reason) AS refund_reason,
    TRIM(refund_status) AS refund_status,
    CAST(requested_at AS timestamp_ntz(0)) AS requested_at,
    CAST(processed_at AS timestamp_ntz(0)) AS processed_at
FROM refunds

