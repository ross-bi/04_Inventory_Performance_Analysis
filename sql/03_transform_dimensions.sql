-- =============================================================================
-- 04 Inventory Performance Analysis
-- Script 03: Transform & Populate Dimension Tables
-- =============================================================================

SET search_path = inventory;


-- dim_date: Generate date spine for full year 2016 + buffer
INSERT INTO dim_date (
    date_key, full_date, year, quarter, month, month_name,
    week_of_year, day_of_week, day_name, is_weekend
)
SELECT
    TO_CHAR(d, 'YYYYMMDD')::INT                         AS date_key,
    d::DATE                                             AS full_date,
    EXTRACT(YEAR   FROM d)::SMALLINT                    AS year,
    EXTRACT(QUARTER FROM d)::SMALLINT                   AS quarter,
    EXTRACT(MONTH  FROM d)::SMALLINT                    AS month,
    TO_CHAR(d, 'Month')                                 AS month_name,
    EXTRACT(WEEK   FROM d)::SMALLINT                    AS week_of_year,
    EXTRACT(ISODOW FROM d)::SMALLINT                    AS day_of_week,
    TO_CHAR(d, 'Day')                                   AS day_name,
    EXTRACT(ISODOW FROM d) IN (6,7)                     AS is_weekend
FROM GENERATE_SERIES('2015-12-01'::DATE, '2017-12-31'::DATE, '1 day') AS d
ON CONFLICT (date_key) DO NOTHING;


-- dim_product: Deduplicate from all source tables
INSERT INTO dim_product (brand, description, size, classification)
SELECT DISTINCT
    b::VARCHAR(100) AS brand,
    d               AS description,
    s               AS size,
    c               AS classification
FROM (
    SELECT "Brand"::VARCHAR AS b, "Description" AS d, "Size" AS s, NULL::VARCHAR AS c
    FROM staging.stg_beg_inventory
    UNION
    SELECT "Brand"::VARCHAR, "Description", "Size", "Classification"
    FROM staging.stg_purchases
    UNION
    SELECT "Brand"::VARCHAR, "Description", "Size", "Classification"
    FROM staging.stg_sales
) combined
ON CONFLICT (brand, description, size) DO UPDATE
    SET classification = EXCLUDED.classification
    WHERE dim_product.classification IS NULL;


-- dim_store: Deduplicate from beginning inventory
INSERT INTO dim_store (store_id, city)
SELECT DISTINCT "Store", "City"
FROM staging.stg_beg_inventory
WHERE "Store" IS NOT NULL
ON CONFLICT (store_id) DO NOTHING;


-- dim_vendor: Deduplicate from purchases + vendor prices
INSERT INTO dim_vendor (vendor_number, vendor_name)
SELECT DISTINCT "VendorNumber", "VendorName"
FROM staging.stg_purchases
WHERE "VendorNumber" IS NOT NULL
UNION
SELECT DISTINCT "VendorNumber", "VendorName"
FROM staging.stg_vendor_prices
WHERE "VendorNumber" IS NOT NULL
ON CONFLICT (vendor_number) DO NOTHING;
