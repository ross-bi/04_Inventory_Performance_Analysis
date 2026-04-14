CREATE OR REPLACE VIEW staging.stg_end_inventory AS
SELECT
    inventory_id,
    NULLIF(TRIM(store), '')::INT                  AS store_id,
    NULLIF(TRIM(brand), '')::INT                  AS brand_id,
    NULLIF(TRIM(description), '')                 AS description,
    NULLIF(TRIM(size), '')                        AS size,
    NULLIF(TRIM(on_hand), '')::INT                AS on_hand_qty,
    NULLIF(TRIM(price), '')::NUMERIC(12,2)        AS unit_price,
    NULLIF(TRIM(end_date), '')::DATE              AS end_date,
    CASE WHEN NULLIF(TRIM(on_hand), '')::INT < 0 THEN TRUE ELSE FALSE END AS flag_negative_on_hand
FROM raw.raw_end_inventory
WHERE inventory_id IS NOT NULL;