-- =============================================================================
-- Phase 3: Staging Layer Transformation (Defensive Casting)
-- Project: 04_Inventory_Performance_Analysis
-- Description: Clean, cast, and standardise raw tables into staging schema
--              - Implemented Defensive Casting: NULLIF for 'Unknown' and '' 
--              - Decimal quantities handled via NUMERIC(10,2)
--              - vendor_name trailing whitespace trimmed
-- =============================================================================

DROP TABLE IF EXISTS staging.stg_sales;
DROP TABLE IF EXISTS staging.stg_purchases;
DROP TABLE IF EXISTS staging.stg_beg_inventory;
DROP TABLE IF EXISTS staging.stg_end_inventory;
DROP TABLE IF EXISTS staging.stg_purchase_prices;
DROP TABLE IF EXISTS staging.stg_invoice_purchases;


-- =============================================================================
-- 1. stg_sales
-- =============================================================================
CREATE TABLE staging.stg_sales AS
SELECT
    inventory_id,
    CAST(NULLIF(NULLIF(TRIM(store), ''), 'Unknown')          AS INTEGER)       AS store,
    CAST(NULLIF(NULLIF(TRIM(brand), ''), 'Unknown')          AS INTEGER)       AS brand,
    description,
    size,
    CAST(NULLIF(NULLIF(TRIM(volume), ''), 'Unknown')         AS NUMERIC(10,2)) AS volume_ml,
    CAST(NULLIF(NULLIF(TRIM(classification), ''), 'Unknown') AS INTEGER)       AS classification,

    CAST(NULLIF(NULLIF(TRIM(sales_quantity), ''), 'Unknown') AS NUMERIC(10,2)) AS sales_quantity,
    CAST(NULLIF(NULLIF(TRIM(sales_dollars), ''), 'Unknown')  AS NUMERIC(12,2)) AS sales_dollars,
    CAST(NULLIF(NULLIF(TRIM(sales_price), ''), 'Unknown')    AS NUMERIC(10,2)) AS sales_price,
    CAST(NULLIF(NULLIF(TRIM(excise_tax), ''), 'Unknown')     AS NUMERIC(10,2)) AS excise_tax,

    CAST(NULLIF(NULLIF(TRIM(sales_date), ''), 'Unknown')     AS DATE)          AS sales_date,
    CAST(NULLIF(NULLIF(TRIM(vendor_no), ''), 'Unknown')      AS INTEGER)       AS vendor_number,
    TRIM(vendor_name)                                                          AS vendor_name,
    NOW()                                                                      AS stg_loaded_at
FROM raw.raw_sales;

CREATE INDEX idx_stg_sales_inventory_id  ON staging.stg_sales (inventory_id);
CREATE INDEX idx_stg_sales_sales_date    ON staging.stg_sales (sales_date);
CREATE INDEX idx_stg_sales_vendor_number ON staging.stg_sales (vendor_number);


-- =============================================================================
-- 2. stg_purchases
-- =============================================================================
CREATE TABLE staging.stg_purchases AS
SELECT
    inventory_id,
    CAST(NULLIF(NULLIF(TRIM(store), ''), 'Unknown')          AS INTEGER)       AS store,
    CAST(NULLIF(NULLIF(TRIM(brand), ''), 'Unknown')          AS INTEGER)       AS brand,
    description,
    size,
    CAST(NULLIF(NULLIF(TRIM(classification), ''), 'Unknown') AS INTEGER)       AS classification,
    CAST(NULLIF(NULLIF(TRIM(vendor_number), ''), 'Unknown')  AS INTEGER)       AS vendor_number,
    TRIM(vendor_name)                                                          AS vendor_name,
    
    CAST(NULLIF(NULLIF(TRIM(purchase_price), ''), 'Unknown') AS NUMERIC(10,2)) AS purchase_price,
    CAST(NULLIF(NULLIF(TRIM(quantity), ''), 'Unknown')       AS NUMERIC(10,2)) AS quantity,
    CAST(NULLIF(NULLIF(TRIM(dollars), ''), 'Unknown')        AS NUMERIC(12,2)) AS dollars,

    CAST(NULLIF(NULLIF(TRIM(po_number), ''), 'Unknown')      AS INTEGER)       AS po_number,
    CAST(NULLIF(NULLIF(TRIM(po_date), ''), 'Unknown')        AS DATE)          AS po_date,
    CAST(NULLIF(NULLIF(TRIM(receiving_date), ''), 'Unknown') AS DATE)          AS receiving_date,
    CAST(NULLIF(NULLIF(TRIM(invoice_date), ''), 'Unknown')   AS DATE)          AS invoice_date,
    CAST(NULLIF(NULLIF(TRIM(pay_date), ''), 'Unknown')       AS DATE)          AS pay_date,
    NOW()                                                                      AS stg_loaded_at
FROM raw.raw_purchases;

CREATE INDEX idx_stg_purchases_inventory_id  ON staging.stg_purchases (inventory_id);
CREATE INDEX idx_stg_purchases_vendor_number ON staging.stg_purchases (vendor_number);
CREATE INDEX idx_stg_purchases_receiving_date ON staging.stg_purchases (receiving_date);


-- =============================================================================
-- 3. stg_beg_inventory
-- =============================================================================
CREATE TABLE staging.stg_beg_inventory AS
SELECT
    inventory_id,
    CAST(NULLIF(NULLIF(TRIM(store), ''), 'Unknown')          AS INTEGER)       AS store,
    city,
    CAST(NULLIF(NULLIF(TRIM(brand), ''), 'Unknown')          AS INTEGER)       AS brand,
    description,
    size,
    CAST(NULLIF(NULLIF(TRIM(on_hand), ''), 'Unknown')        AS NUMERIC(10,2)) AS on_hand,
    CAST(NULLIF(NULLIF(TRIM(price), ''), 'Unknown')          AS NUMERIC(10,2)) AS price,
    CAST(NULLIF(NULLIF(TRIM(start_date), ''), 'Unknown')     AS DATE)          AS start_date,
    NOW()                                                                      AS stg_loaded_at
FROM raw.raw_beg_inventory;

CREATE INDEX idx_stg_beg_inv_inventory_id ON staging.stg_beg_inventory (inventory_id);
CREATE INDEX idx_stg_beg_inv_store        ON staging.stg_beg_inventory (store);


-- =============================================================================
-- 4. stg_end_inventory
-- =============================================================================
CREATE TABLE staging.stg_end_inventory AS
SELECT
    inventory_id,
    CAST(NULLIF(NULLIF(TRIM(store), ''), 'Unknown')          AS INTEGER)       AS store,
    city,
    CAST(NULLIF(NULLIF(TRIM(brand), ''), 'Unknown')          AS INTEGER)       AS brand,
    description,
    size,
    CAST(NULLIF(NULLIF(TRIM(on_hand), ''), 'Unknown')        AS NUMERIC(10,2)) AS on_hand,
    CAST(NULLIF(NULLIF(TRIM(price), ''), 'Unknown')          AS NUMERIC(10,2)) AS price,
    CAST(NULLIF(NULLIF(TRIM(end_date), ''), 'Unknown')       AS DATE)          AS end_date,
    NOW()                                                                      AS stg_loaded_at
FROM raw.raw_end_inventory;

CREATE INDEX idx_stg_end_inv_inventory_id ON staging.stg_end_inventory (inventory_id);
CREATE INDEX idx_stg_end_inv_store        ON staging.stg_end_inventory (store);


-- =============================================================================
-- 5. stg_purchase_prices
-- =============================================================================
CREATE TABLE staging.stg_purchase_prices AS
SELECT
    CAST(NULLIF(NULLIF(TRIM(brand), ''), 'Unknown')          AS INTEGER)       AS brand,
    description,
    size,
    CAST(NULLIF(NULLIF(TRIM(volume), ''), 'Unknown')         AS NUMERIC(10,2)) AS volume_ml,
    CAST(NULLIF(NULLIF(TRIM(classification), ''), 'Unknown') AS INTEGER)       AS classification,

    NULLIF(CAST(NULLIF(NULLIF(TRIM(price), ''), 'Unknown')   AS NUMERIC(10,2)), 0) AS retail_price,
    NULLIF(CAST(NULLIF(NULLIF(TRIM(purchase_price), ''), 'Unknown') AS NUMERIC(10,2)), 0) AS purchase_price,

    CASE
        WHEN NULLIF(CAST(NULLIF(NULLIF(TRIM(price), ''), 'Unknown') AS NUMERIC(10,2)), 0) IS NOT NULL
         AND NULLIF(CAST(NULLIF(NULLIF(TRIM(purchase_price), ''), 'Unknown') AS NUMERIC(10,2)), 0) IS NOT NULL
        THEN ROUND(
            (CAST(NULLIF(NULLIF(TRIM(price), ''), 'Unknown') AS NUMERIC(10,2)) - CAST(NULLIF(NULLIF(TRIM(purchase_price), ''), 'Unknown') AS NUMERIC(10,2)))
            / NULLIF(CAST(NULLIF(NULLIF(TRIM(price), ''), 'Unknown') AS NUMERIC(10,2)), 0) * 100
        , 2)
        ELSE NULL
    END                                                                        AS gross_margin_pct,

    CAST(NULLIF(NULLIF(TRIM(vendor_number), ''), 'Unknown')  AS INTEGER)       AS vendor_number,
    TRIM(vendor_name)                                                          AS vendor_name,
    NOW()                                                                      AS stg_loaded_at
FROM raw.raw_purchase_prices;

CREATE INDEX idx_stg_purchase_prices_brand ON staging.stg_purchase_prices (brand);
CREATE INDEX idx_stg_purchase_prices_vendor ON staging.stg_purchase_prices (vendor_number);


-- =============================================================================
-- 6. stg_invoice_purchases
-- =============================================================================
CREATE TABLE staging.stg_invoice_purchases AS
SELECT
    CAST(NULLIF(NULLIF(TRIM(vendor_number), ''), 'Unknown')  AS INTEGER)       AS vendor_number,
    TRIM(vendor_name)                                                          AS vendor_name,
    CAST(NULLIF(NULLIF(TRIM(invoice_date), ''), 'Unknown')   AS DATE)          AS invoice_date,
    CAST(NULLIF(NULLIF(TRIM(po_number), ''), 'Unknown')      AS INTEGER)       AS po_number,
    CAST(NULLIF(NULLIF(TRIM(po_date), ''), 'Unknown')        AS DATE)          AS po_date,
    CAST(NULLIF(NULLIF(TRIM(pay_date), ''), 'Unknown')       AS DATE)          AS pay_date,
    
    CAST(NULLIF(NULLIF(TRIM(quantity), ''), 'Unknown')       AS NUMERIC(10,2)) AS quantity,
    CAST(NULLIF(NULLIF(TRIM(dollars), ''), 'Unknown')        AS NUMERIC(12,2)) AS dollars,
    CAST(NULLIF(NULLIF(TRIM(freight), ''), 'Unknown')        AS NUMERIC(10,2)) AS freight,
    approval,

    CASE
        WHEN CAST(NULLIF(NULLIF(TRIM(invoice_date), ''), 'Unknown') AS DATE) > '2016-12-31' THEN TRUE
        ELSE FALSE
    END                                                                        AS is_carryover_invoice,
    NOW()                                                                      AS stg_loaded_at
FROM raw.raw_invoice_purchases;

CREATE INDEX idx_stg_invoice_vendor_number ON staging.stg_invoice_purchases (vendor_number);
CREATE INDEX idx_stg_invoice_date          ON staging.stg_invoice_purchases (invoice_date);

=============================================================================
-- POST-LOAD: Row count verification
-- Expected: matches raw counts exactly
-- =============================================================================
SELECT 'stg_sales'              AS table_name, COUNT(*) AS row_count FROM staging.stg_sales
UNION ALL
SELECT 'stg_purchases',                         COUNT(*) FROM staging.stg_purchases
UNION ALL
SELECT 'stg_beg_inventory',                     COUNT(*) FROM staging.stg_beg_inventory
UNION ALL
SELECT 'stg_end_inventory',                     COUNT(*) FROM staging.stg_end_inventory
UNION ALL
SELECT 'stg_purchase_prices',                   COUNT(*) FROM staging.stg_purchase_prices
UNION ALL
SELECT 'stg_invoice_purchases',                 COUNT(*) FROM staging.stg_invoice_purchases
ORDER BY table_name;