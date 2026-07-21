WITH stg_orders AS (
    SELECT 
        *
    FROM {{ref ("stg_lumen_loom__orders")}}
),

exchange_rates AS (
    SELECT
        *
    FROM {{ref("lumen_loom__exchange_rates")}}
),

converted_orders AS (
    SELECT
        o.order_key,
        o.order_id,
        o.order_status,
        o.order_amount AS original_amount,
        o.currency AS original_currency,
        -- converting order_amount to USD using the seed table
        COALESCE (e.usd_rate, 1) AS exchange_rate,
        ROUND (o.order_amount * COALESCE (e.usd_rate, 1), 2) AS amount_usd,
        'USD' AS currency,
        -- some created_at > updated_at and vice versa, so i used the LEAST & GREATEST command to correct it
        LEAST (COALESCE(o.created_at, o.updated_at), COALESCE(o.updated_at, o.created_at)) AS created_at,
        GREATEST (COALESCE(o.created_at, o.updated_at), COALESCE(o.updated_at, o.created_at)) AS updated_at
    FROM stg_orders o
    LEFT JOIN exchange_rates e
    ON o.currency = e.currency
)

-- Final int_orders
SELECT
    *
FROM converted_orders