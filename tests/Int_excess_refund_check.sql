--Check to ensure that refundment payment do not exceeed the initial payment. 
--it ust return zero rows to pass the test.

SELECT 
    r.refund_id,
    r.payment_id,
    r.refund_amount_usd,
    p.payment_amount_usd
FROM {{ ref('int_lumen_loom__refunds') }} r
JOIN {{ ref('int_lumen_loom__payments') }} p
    ON r.payment_id = p.payment_id
WHERE r.refund_amount_usd > p.payment_amount_usd