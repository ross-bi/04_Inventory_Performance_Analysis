CREATE OR REPLACE VIEW staging.stg_purchase_prices AS
SELECT
    NULLIF(TRIM(brand), '')::INT                  AS brand_id,
    NULLIF(TRIM(description), '')                 AS description,
    NULLIF(TRIM(price), '')::NUMERIC(12,2)        AS retail_price,
    NULLIF(TRIM(size), '')                        AS size,
    NULLIF(TRIM(volume), '')::INT                 AS volume_ml,
    NULLIF(TRIM(classification), '')::INT         AS classification,
    NULLIF(TRIM(purchase_price), '')::NUMERIC(12,2) AS purchase_price,
    NULLIF(TRIM(vendor_no), '')::INT              AS vendor_no,
    NULLIF(TRIM(vendor_name), '')                 AS vendor_name
FROM raw.raw_purchase_prices;