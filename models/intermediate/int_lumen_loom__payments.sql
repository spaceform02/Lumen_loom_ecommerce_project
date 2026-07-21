WITH stg_payments AS (
    SELECT 
        *
    FROM {{ref ("stg_lumen_loom__payments")}}
),

exchange_rates AS (
    SELECT
        *
    FROM {{ref("lumen_loom__exchange_rates")}}
),

converted_payments AS (
    SELECT
        p.payment_key,
        p.payment_id,
        p.order_id,
        p.payment_status,
        p.amount AS original_payment_amount,
        p.currency AS original_currency,
        p.payment_method,
        p.gateway_fee AS original_gateway_fee,
        -- converting order_amount to USD using the seed table
        COALESCE(e.usd_rate, 1) AS exchange_rate,
        ROUND (p.amount * COALESCE(e.usd_rate, 1), 2) AS payment_amount_usd,
        ROUND (p.gateway_fee * COALESCE(e.usd_rate, 1), 2) AS gateway_fee_usd, 
        'USD' AS currency,
        p.attempted_at,
        p.processed_at
    FROM stg_payments p
    LEFT JOIN exchange_rates e
    ON p.currency = e.currency
),

--For the payment, some of the payment were dupicated, such as repeated attempt after failure 
--and some double payment. so there is a need to identify them, I wont delete them, so that 
--I can use them as audit in the mart layer, the earliest succesful payment will be using 
--to calculate revenue in the mart layer

ranked_payment AS (
    SELECT
        *,
        ROW_NUMBER () OVER (
            PARTITION BY order_id, payment_status
            ORDER BY processed_at ASC) as payment_rank
    FROM converted_payments
)


--Final Int_payment
SELECT
    payment_key,
    payment_id,
    order_id,
    payment_status,
    original_payment_amount,
    original_currency,
    payment_method,
    original_gateway_fee,
    exchange_rate,
    payment_amount_usd,
    gateway_fee_usd,
    currency,
    attempted_at,
    processed_at,
    --sorting the payment success
    --correct payment
    CASE 
        WHEN payment_status = 'succeeded' AND payment_rank = 1 THEN TRUE 
        ELSE FALSE
    END AS is_valid_revenue,
    --duplicate payment
     CASE 
        WHEN payment_status = 'succeeded' AND payment_rank > 1 THEN TRUE 
        ELSE FALSE
    END AS is_duplicate_payment,
    --failed attempts
     CASE 
        WHEN payment_status = 'failed' THEN TRUE 
        ELSE FALSE
    END AS is_failed_attempt
FROM ranked_payment