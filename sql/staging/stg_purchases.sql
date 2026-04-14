CREATE OR REPLACE VIEW staging.stg_purchases AS
SELECT
    inventory_id,
    NULLIF(TRIM(store), '')::INT                   AS store_id,
    NULLIF(TRIM(brand), '')::INT                   AS brand_id,
    NULLIF(TRIM(vendor_number), '')::INT           AS vendor_no,
    NULLIF(TRIM(po_number), '')::INT               AS po_number,
    NULLIF(TRIM(po_date), '')::DATE                AS po_date,
    NULLIF(TRIM(receiving_date), '')::DATE         AS receiving_date,
    NULLIF(TRIM(invoice_date), '')::DATE           AS invoice_date,
    NULLIF(TRIM(pay_date), '')::DATE               AS pay_date,
    NULLIF(TRIM(quantity), '')::INT                AS quantity,
    NULLIF(TRIM(dollars), '')::NUMERIC(12,2)       AS dollars,
    NULLIF(TRIM(freight), '')::NUMERIC(12,2)       AS freight,
    NULLIF(TRIM(volume), '')::INT                  AS volume_ml,
    CASE WHEN NULLIF(TRIM(quantity), '')::INT <= 0 THEN TRUE ELSE FALSE END AS flag_invalid_purchase_quantity
FROM raw.raw_purchases
WHERE inventory_id IS NOT NULL;