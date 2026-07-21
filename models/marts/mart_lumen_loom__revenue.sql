--orders table
WITH int_orders AS (
    SELECT 
        order_key,
        order_id,
        order_status,
        amount_usd AS order_amount_usd,
        created_at,
        updated_at AS order_updated_at
    FROM {{ ref("int_lumen_loom__orders")}}
),

--Categorized Intermediate tables with unique order_id
categorized_payments AS (
    SELECT
        order_id,
        MAX(CASE WHEN is_valid_revenue = TRUE THEN payment_key END) AS payment_key,
        MAX(CASE WHEN is_valid_revenue = TRUE THEN payment_id END) AS payment_id,
        ROUND(SUM(CASE WHEN is_valid_revenue = TRUE THEN payment_amount_usd ELSE 0 END), 2) AS valid_payment_usd,
        MAX(CASE WHEN is_valid_revenue = TRUE THEN processed_at END) AS valid_payment_processed_at,
        ROUND(SUM(CASE WHEN is_duplicate_payment = TRUE THEN payment_amount_usd ELSE 0 END), 2) AS duplicate_payment_usd,
        MAX(CASE WHEN is_duplicate_payment = TRUE THEN processed_at END) AS duplicate_processed_at,
        SUM(CASE WHEN is_failed_attempt = TRUE THEN 1 ELSE 0 END) AS failed_payment_count,
        ROUND(SUM(CASE WHEN is_valid_revenue = TRUE OR is_duplicate_payment = TRUE THEN gateway_fee_usd ELSE 0 END), 2) AS total_gateway_fee_usd
    FROM {{ ref("int_lumen_loom__payments")}}
    GROUP BY order_id
), 

--refunds table
int_refunds AS (
    SELECT 
        refund_key,
        refund_id,
        payment_id,
        order_id,
        refund_amount_usd,
        refund_reason,
        requested_at AS refund_requested_at,
        processed_at AS refund_processed_at
    FROM {{ ref("int_lumen_loom__refunds")}}
),


--shiiping table
int_shipping AS (
    SELECT
        shipment_key,
        shipment_id,
        order_id,
        shipping_cost,
        derived_shipping_status AS shipping_status,
        delivered_at AS delivery_time
    FROM {{ ref("int_lumen_loom__shipping")}}
)

SELECT
    --order metrics
    o.order_key,
    o.order_id,
    p.payment_id,
    r.refund_id,
    s.shipment_id,
    --order metrics
    o.order_status,
    o.order_amount_usd,
    o.order_updated_at,
    --payment metrics
    COALESCE(p.valid_payment_usd, 0) AS valid_payment_usd,
    COALESCE(p.duplicate_payment_usd, 0) AS duplicate_payment_usd,
    p.valid_payment_processed_at,
    p.duplicate_processed_at,
    COALESCE(p.failed_payment_count, 0) AS failed_payment_count,
    --refund metrics
    COALESCE(r.refund_amount_usd, 0) AS refund_amount_usd,
    r.refund_reason,
    r.refund_processed_at,
    --shipping metrics
    s.shipping_cost,
    s.shipping_status,
    s.delivery_time,
    --logic for leakage cancellation
    CASE 
        WHEN o.order_status = 'cancelled'
        AND COALESCE(p.valid_payment_usd, 0) > 0
        AND COALESCE(r.refund_amount_usd, 0) = 0 
        THEN TRUE ELSE FALSE 
        END AS cancellation_leakage
FROM int_orders o
LEFT JOIN categorized_payments p
    ON o.order_id = p.order_id
LEFT JOIN int_refunds r
    ON o.order_id = r.order_id
LEFT JOIN int_shipping s
    ON o.order_id = s.order_id