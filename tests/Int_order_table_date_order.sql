-- This test checks that updated_at is usually older than created_at, 
--for it to pass the test, it must return zero rows

SELECT 
    order_id,
    created_at,
    updated_at
FROM {{ ref('int_lumen_loom__orders') }}
WHERE updated_at < created_at