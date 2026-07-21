WITH stg_shippings AS (
    SELECT 
        *
    FROM {{ref ("stg_lumen_loom__shipping")}}
),


--This CTE will based on the shipping status and availability of shipping_at and 
--delivered_at will relabelled the shipping status. The CTE will also identify the 
--shippings with the API error.

enriched_shipping AS (
    SELECT
        shippment_key AS shipment_key,
        shipment_id,
        order_id,
        carrier,
        shipping_cost,
        status AS original_api_status,
        --correct shipping status based on the data
        CASE
            WHEN delivered_at IS NOT NULL THEN 'delivered'
            WHEN shipped_at IS NOT NULL AND delivered_at IS NULL THEN 'in_transit'
            ELSE status
        END AS derived_shipping_status,
        shipped_at,
        delivered_at,
        --Here I flagged the API errors
        CASE
            WHEN shipped_at IS NULL AND delivered_at IS NOT NULL THEN TRUE
            ELSE FALSE
            END AS api_error_flag
    FROM stg_shippings
)

--final Intermediate shipping table
SELECT
    *
FROM enriched_shipping