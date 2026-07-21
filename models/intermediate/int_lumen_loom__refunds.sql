WITH stg_refunds AS (
    SELECT 
        *
    FROM {{ref ("stg_lumen_loom__refunds")}}
),

exchange_rates AS (
    SELECT
        *
    FROM {{ref("lumen_loom__exchange_rates")}}
),

converted_refunds AS (
    SELECT
        r.refund_key, 
        r.refund_id,
        r.payment_id,
        r.order_id,
        r.refund_amount AS original_refund_amount,
        r.currency AS original_currency,
        -- converting order_amount to USD using the seed table
        COALESCE (e.usd_rate, 1) AS exchange_rate,
        ROUND (r.refund_amount * COALESCE(e.usd_rate, 1), 2) AS refund_amount_usd,
        'USD' AS currency,
        r.refund_reason,
        r.refund_status,
        r.requested_at,
        r.processed_at
    FROM stg_refunds r
    INNER JOIN exchange_rates e
    ON r.currency = e.currency
)

--Final Intermediate refund table
SELECT
    *
FROM converted_refunds
