WITH fact_revenue AS (
    SELECT 
        *
    FROM {{ref("mart_lumen_loom__revenue")}}
),


--EXTRACT each month from the valid payment, duplicate payment, refund and delivery time 
--using DATE_TRUNC because the dates range between 20244 and 2025.
combined_reporting_months AS (
    --Valid payment reporting months
    SELECT 
        DISTINCT DATE_TRUNC('month', valid_payment_processed_at) AS reporting_month
    FROM fact_revenue
    WHERE valid_payment_processed_at IS NOT NULL
    
    UNION

    --Duplicate payment reporting months
    SELECT 
        DISTINCT DATE_TRUNC('month', DUPLICATE_PROCESSED_AT) AS reporting_month
    FROM fact_revenue
    WHERE duplicate_processed_at IS NOT NULL

    UNION

    --Refunds reporting months
    SELECT 
        DISTINCT DATE_TRUNC('month', refund_processed_at) AS reporting_month
    FROM fact_revenue
    WHERE refund_processed_at IS NOT NULL
    
    UNION

    --Shipping time reporting months
    SELECT 
        DISTINCT DATE_TRUNC('month', delivery_time) AS reporting_month
    FROM fact_revenue
    WHERE delivery_time IS NOT NULL
),

--Calculation for valid payment, duplicate and cancellation leakages needed by Operations team
--Here revenue is recognised by Operations when the payment was received (valid_payment_processed_at)
--Duplicate have a different time when it was received (duplicate_processed_at), but I did it together 
--with the valid payment because the differences in the time for both valid and duplicate are 
--only few seconds or minutes. 
finance_revenue AS (
    SELECT
        DATE_TRUNC('month', valid_payment_processed_at) AS reporting_month,
        SUM(valid_payment_usd) AS fin_gross_revenue,
        SUM(duplicate_payment_usd) AS fin_duplicate_payment,
        SUM(CASE WHEN cancellation_leakage = TRUE THEN valid_payment_usd ELSE 0 END) AS fin_cancellation_leakage
    FROM fact_revenue
    WHERE valid_payment_processed_at IS NOT NULL
    GROUP BY 1 
),

--Calacualted revenue for completed, paid and delivered orders
--Here payment is recognised when the order has been delivered (delivery_time)
delivered_revenue AS (
    SELECT
        DATE_TRUNC('month', delivery_time) AS reporting_month,
        SUM(CASE WHEN shipping_status = 'delivered' THEN valid_payment_usd ELSE 0 END) AS ops_delivered_revenue
    FROM fact_revenue
    WHERE delivery_time IS NOT NULL
    GROUP BY 1
),

--Aggregate refunds by months.
--Here refund is calculated when the refund was processed (refund_processed_at)
refunds AS (
    SELECT
        DATE_TRUNC('month', refund_processed_at) AS reporting_month,
        SUM(refund_amount_usd) AS monthly_refund
    FROM fact_revenue
    WHERE refund_processed_at IS NOT NULL
    GROUP BY 1
)

---Reconcialliation Table between Operations and Finance
SELECT
    m.reporting_month AS periods,
    TO_CHAR(m.reporting_month, 'MMMM YYYY') AS reporting_month,
    --Finance Metrics
    COALESCE(f.fin_gross_revenue, 0) AS finance_gross_revenue,
    COALESCE(f.fin_duplicate_payment, 0) AS aggregate_duplicate_payment,
    COALESCE(f.fin_cancellation_leakage, 0) AS aggregate_cancellation_leakage,
    COALESCE(f.fin_gross_revenue, 0) - COALESCE(f.fin_cancellation_leakage, 0) AS finance_net_revenue,
    --Operations Metrics
    COALESCE(d.ops_delivered_revenue, 0) AS operation_gross_revenue,
    COALESCE(r.monthly_refund, 0) AS refunds,
    COALESCE(d.ops_delivered_revenue, 0) - COALESCE(r.monthly_refund, 0) AS operation_net_revenue,
    --Timing
    --Here i deduce it is the differences between Finance net revenue and Operation gross revenue
    (COALESCE(f.fin_gross_revenue, 0) - COALESCE(f.fin_cancellation_leakage, 0)) - (COALESCE(d.ops_delivered_revenue, 0)) AS timing_diff,
    --refund rate
    ROUND(COALESCE(r.monthly_refund, 0) / NULLIF(d.ops_delivered_revenue, 0) * 100, 2) AS refund_rate_pct
FROM combined_reporting_months m
LEFT JOIN finance_revenue f
ON m.reporting_month = f.reporting_month
LEFT JOIN delivered_revenue d
ON m.reporting_month = d.reporting_month
LEFT JOIN refunds r
ON m.reporting_month = r.reporting_month
ORDER BY 1 ASC