-- =============================================================
-- 01_populate_dimensions.sql
-- Populates dimension tables from staging.
-- Run AFTER 00_data_quality_check.sql (no blocking errors).
-- dim_date is pre-populated in 02_create_dimensions.sql.
-- =============================================================

-- ------------------------------------------------------------
-- dim_store  (union of beg + end inventory for complete list)
-- ------------------------------------------------------------
INSERT INTO warehouse.dim_store (store_id, city)
SELECT DISTINCT store_id, city
FROM (
    SELECT store_id, city FROM staging.stg_beg_inventory
    UNION
    SELECT store_id, city FROM staging.stg_end_inventory
) s
ORDER BY store_id
ON CONFLICT (store_id) DO UPDATE SET city = EXCLUDED.city;

-- ------------------------------------------------------------
-- dim_vendor  (union from purchase_prices + purchases + sales)
-- ------------------------------------------------------------
INSERT INTO warehouse.dim_vendor (vendor_number, vendor_name)
SELECT DISTINCT vendor_number, TRIM(vendor_name)
FROM (
    SELECT vendor_number, vendor_name FROM staging.stg_purchase_prices
    UNION
    SELECT vendor_number, vendor_name FROM staging.stg_purchases
    UNION
    SELECT vendor_no,     vendor_name FROM staging.stg_sales
) v
WHERE vendor_number IS NOT NULL
ORDER BY vendor_number
ON CONFLICT (vendor_number) DO UPDATE
    SET vendor_name = EXCLUDED.vendor_name;

-- ------------------------------------------------------------
-- dim_product  (master = stg_purchase_prices, fallback = beg_inv)
-- classification_name: 1=Spirits  2=Wine  3=Beer  else=Other
-- ------------------------------------------------------------
INSERT INTO warehouse.dim_product (
    brand_id, description, size, volume_ml, classification,
    classification_name, retail_price, purchase_price,
    gross_margin_pct, vendor_number, vendor_name
)
SELECT
    pp.brand_id,
    TRIM(pp.description),
    TRIM(pp.size),
    NULLIF(REGEXP_REPLACE(pp.volume, '[^0-9]', '', 'g'), '')::INT  AS volume_ml,
    pp.classification,
    CASE pp.classification
        WHEN 1 THEN 'Spirits'
        WHEN 2 THEN 'Wine'
        WHEN 3 THEN 'Beer'
        ELSE 'Other'
    END                                                             AS classification_name,
    pp.price                                                        AS retail_price,
    pp.purchase_price,
    CASE WHEN pp.price > 0
         THEN ROUND((pp.price - pp.purchase_price) / pp.price, 4)
         ELSE NULL
    END                                                             AS gross_margin_pct,
    pp.vendor_number,
    TRIM(pp.vendor_name)
FROM staging.stg_purchase_prices pp
ON CONFLICT (brand_id) DO UPDATE
    SET retail_price     = EXCLUDED.retail_price,
        purchase_price   = EXCLUDED.purchase_price,
        gross_margin_pct = EXCLUDED.gross_margin_pct;

-- Fallback: products in beg_inventory but missing from purchase_prices
-- (purchase_price and gross_margin_pct will be NULL for these rows)
INSERT INTO warehouse.dim_product (brand_id, description, size, retail_price)
SELECT DISTINCT
    b.brand_id,
    TRIM(b.description),
    TRIM(b.size),
    b.price
FROM staging.stg_beg_inventory b
WHERE NOT EXISTS (
    SELECT 1 FROM warehouse.dim_product dp WHERE dp.brand_id = b.brand_id
)
ON CONFLICT (brand_id) DO NOTHING;

-- ------------------------------------------------------------
-- dim_vendor: back-fill avg_lead_time_days from stg_purchases
-- FIX: po_date and receiving_date are now VARCHAR(20) in staging;
--      must use TO_DATE() before computing date arithmetic.
-- ------------------------------------------------------------
UPDATE warehouse.dim_vendor dv
SET avg_lead_time_days = sub.avg_lead
FROM (
    SELECT
        vendor_number,
        ROUND(
            AVG(
                TO_DATE(receiving_date, 'YYYY-MM-DD')
                - TO_DATE(po_date,       'YYYY-MM-DD')
            )::NUMERIC
        , 2) AS avg_lead
    FROM staging.stg_purchases
    WHERE receiving_date IS NOT NULL AND TRIM(receiving_date) <> ''
      AND po_date        IS NOT NULL AND TRIM(po_date)        <> ''
      -- only rows where receiving >= po (filter bad data)
      AND TO_DATE(receiving_date, 'YYYY-MM-DD')
          >= TO_DATE(po_date, 'YYYY-MM-DD')
    GROUP BY vendor_number
) sub
WHERE dv.vendor_number = sub.vendor_number;
