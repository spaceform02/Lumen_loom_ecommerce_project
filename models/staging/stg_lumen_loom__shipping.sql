WITH shipping AS (
    SELECT *
    FROM {{source('lumen_loom', 'raw_shipping')}}
)

SELECT
    {{dbt_utils.generate_surrogate_key(['shipment_id', 'order_id'])}} AS shippment_key,
    shipment_id,
    order_id,
    TRIM(carrier) AS carrier,
    shipping_cost,
    TRIM(status) AS status,
    CAST(shipped_at AS timestamp_ntz(0)) AS shipped_at,
    CAST(delivered_at AS timestamp_ntz(0)) AS delivered_at
FROM shipping
