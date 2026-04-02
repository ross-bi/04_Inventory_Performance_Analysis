-- =============================================================
-- 01_populate_dimensions.sql
-- Populates dimension tables from staging
-- dim_date is already populated in 02_create_dimensions.sql
-- =============================================================

-- ------------------------------------------------------------
-- dim_store  (from beg + end inventory union for full store list)
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
-- dim_vendor  (from purchase prices + purchases + sales)
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
-- dim_product  (master = stg_purchase_prices, enriched with beg inv price)
-- classification_name: 1=Spirits, 2=Wine, 3=Beer, 4=Other
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
    -- Extract numeric mL from volume text; fallback NULL
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
    SET retail_price    = EXCLUDED.retail_price,
        purchase_price  = EXCLUDED.purchase_price,
        gross_margin_pct = EXCLUDED.gross_margin_pct;

-- Add products that appear in inventory but not in purchase_prices
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

-- Update avg_lead_time_days in dim_vendor after purchases are available
UPDATE warehouse.dim_vendor dv
SET avg_lead_time_days = sub.avg_lead
FROM (
    SELECT
        vendor_number,
        ROUND(AVG(receiving_date - po_date), 2) AS avg_lead
    FROM staging.stg_purchases
    WHERE receiving_date IS NOT NULL AND po_date IS NOT NULL
      AND receiving_date >= po_date
    GROUP BY vendor_number
) sub
WHERE dv.vendor_number = sub.vendor_number;
