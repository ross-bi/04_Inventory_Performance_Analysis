CREATE OR REPLACE VIEW staging.stg_sales AS
SELECT
    inventory_id,
    NULLIF(TRIM(store), '')::INT                    AS store_id,
    NULLIF(TRIM(brand), '')::INT                    AS brand_id,
    NULLIF(TRIM(description), '')                   AS description,
    NULLIF(TRIM(size), '')                          AS size,
    NULLIF(TRIM(sales_quantity), '')::INT           AS sales_quantity,
    NULLIF(TRIM(sales_dollars), '')::NUMERIC(12,2)  AS sales_dollars,
    NULLIF(TRIM(sales_price), '')::NUMERIC(12,2)    AS sales_price,
    NULLIF(TRIM(sales_date), '')::DATE              AS sales_date,
    NULLIF(TRIM(volume), '')::INT                   AS volume_ml,
    NULLIF(TRIM(classification), '')::INT           AS classification,
    NULLIF(TRIM(excise_tax), '')::NUMERIC(12,2)     AS excise_tax,
    NULLIF(TRIM(vendor_no), '')::INT                AS vendor_no,
    NULLIF(TRIM(vendor_name), '')                   AS vendor_name,
    CASE WHEN NULLIF(TRIM(sales_quantity), '')::INT <= 0 THEN TRUE ELSE FALSE END AS flag_invalid_sales_quantity,
    CASE WHEN NULLIF(TRIM(sales_price), '')::NUMERIC(12,2) <= 0 THEN TRUE ELSE FALSE END AS flag_invalid_sales_price
FROM raw.raw_sales
WHERE inventory_id IS NOT NULL;