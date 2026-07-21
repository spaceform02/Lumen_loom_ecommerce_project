-- This test checks that delivered_at is usually older than shipped_at, 
--for it to pass the test, it must return zero rows 

SELECT 
    shipment_id,
    shipped_at,
    delivered_at
FROM {{ ref('int_lumen_loom__shipping') }}
WHERE delivered_at < shipped_at