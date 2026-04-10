-- ============================================================
-- FILE: sql/02_elt/02_transform_staging.sql
-- PURPOSE: Layer 2 ELT - Cleanse, Standardise, DQ Flag
-- ============================================================

-- ============================================================
-- 1. stg_sales
-- Transformations:
--   - Decompose inventory_id into store_id, store_name, brand_id
--   - TRIM vendor_name, UPPER size
--   - Validate: qty > 0, dollars > 0, dollars ≈ price * qty
--   - Extract date parts for partitioning
-- ============================================================
DROP TABLE IF EXISTS staging.stg_sales;
CREATE TABLE staging.stg_sales AS
SELECT
    inventory_id,
    -- Decompose composite key
    SPLIT_PART(inventory_id, '_', 1)::INTEGER                   AS store_id,
    SPLIT_PART(inventory_id, '_', 2)                            AS store_name,
    SPLIT_PART(inventory_id, '_', 3)::INTEGER                   AS brand_id,
    store,
    brand,
    TRIM(description)                                           AS description,
    UPPER(TRIM(size))                                           AS size_std,
    sales_quantity,
    sales_dollars,
    sales_price,
    sales_date,
    EXTRACT(YEAR  FROM sales_date)::SMALLINT                    AS sale_year,
    EXTRACT(MONTH FROM sales_date)::SMALLINT                    AS sale_month,
    EXTRACT(QUARTER FROM sales_date)::SMALLINT                  AS sale_quarter,
    volume,
    classification,
    CASE classification
        WHEN 1 THEN 'Spirits'
        WHEN 2 THEN 'Wine'
        WHEN 3 THEN 'Beer'
        ELSE 'Other'
    END                                                         AS class_name,
    excise_tax,
    vendor_no,
    TRIM(vendor_name)                                           AS vendor_name_clean,
    -- Data Quality Flag
    CASE
        WHEN sales_quantity IS NULL OR sales_quantity <= 0
            THEN 'INVALID_QTY'
        WHEN sales_dollars IS NULL OR sales_dollars <= 0
            THEN 'INVALID_AMT'
        WHEN sales_price IS NULL OR sales_price <= 0
            THEN 'INVALID_PRICE'
        WHEN ABS(sales_dollars - (sales_price * sales_quantity)) > 0.05
            THEN 'AMOUNT_MISMATCH'
        WHEN SPLIT_PART(inventory_id, '_', 3) ~ '^[0-9]+$' = FALSE
            THEN 'BAD_INVENTORY_ID'
        ELSE 'VALID'
    END                                                         AS dq_flag,
    _loaded_at
FROM raw.sales;

-- ============================================================
-- 2. stg_purchases
-- Transformations:
--   - Decompose inventory_id
--   - Validate amount: dollars ≈ purchase_price * quantity
--   - Flag late payments (pay_date > invoice_date + 30 days)
-- ============================================================
DROP TABLE IF EXISTS staging.stg_purchases;
CREATE TABLE staging.stg_purchases AS
SELECT
    inventory_id,
    SPLIT_PART(inventory_id, '_', 1)::INTEGER                   AS store_id,
    SPLIT_PART(inventory_id, '_', 2)                            AS store_name,
    SPLIT_PART(inventory_id, '_', 3)::INTEGER                   AS brand_id,
    store,
    brand,
    TRIM(description)                                           AS description,
    UPPER(TRIM(size))                                           AS size_std,
    vendor_number                                               AS vendor_id,
    TRIM(vendor_name)                                           AS vendor_name_clean,
    po_number,
    po_date,
    receiving_date,
    invoice_date,
    pay_date,
    purchase_price,
    quantity,
    dollars,
    classification,
    CASE classification
        WHEN 1 THEN 'Spirits'
        WHEN 2 THEN 'Wine'
        WHEN 3 THEN 'Beer'
        ELSE 'Other'
    END                                                         AS class_name,
    -- Lead time: days from PO to receiving
    (receiving_date - po_date)                                  AS lead_time_days,
    -- Payment delay: days from invoice to actual payment
    (pay_date - invoice_date)                                   AS payment_days,
    -- Data Quality Flag
    CASE
        WHEN quantity IS NULL OR quantity <= 0
            THEN 'INVALID_QTY'
        WHEN dollars IS NULL OR dollars <= 0
            THEN 'INVALID_AMT'
        WHEN ABS(dollars - (purchase_price * quantity)) > 0.05
            THEN 'AMOUNT_MISMATCH'
        WHEN receiving_date < po_date
            THEN 'RECEIVING_BEFORE_PO'
        ELSE 'VALID'
    END                                                         AS dq_flag,
    _loaded_at
FROM raw.purchases;

-- ============================================================
-- 3. stg_inventory_snapshot
-- Combine beg + end inventory into unified snapshot table
-- Add snapshot_type flag: 'BEG' / 'END'
-- ============================================================
DROP TABLE IF EXISTS staging.stg_inventory_snapshot;
CREATE TABLE staging.stg_inventory_snapshot AS

SELECT
    inventory_id,
    store,
    city,
    brand                                                       AS brand_id,
    TRIM(description)                                           AS description,
    UPPER(TRIM(size))                                           AS size_std,
    on_hand,
    price,
    start_date                                                  AS snapshot_date,
    'BEG'                                                       AS snapshot_type,
    CASE WHEN on_hand < 0 THEN 'NEGATIVE_STOCK' ELSE 'VALID' END AS dq_flag
FROM raw.beg_inventory

UNION ALL

SELECT
    inventory_id,
    store,
    city,
    brand,
    TRIM(description),
    UPPER(TRIM(size)),
    on_hand,
    price,
    end_date,
    'END',
    CASE WHEN on_hand < 0 THEN 'NEGATIVE_STOCK' ELSE 'VALID' END
FROM raw.end_inventory;

-- ============================================================
-- 4. Deduplication safety check for stg_sales
-- Removes exact duplicates (same inventory_id + date + qty + price)
-- Keeps latest _loaded_at row
-- ============================================================
DELETE FROM staging.stg_sales s1
USING staging.stg_sales s2
WHERE
    s1.inventory_id  = s2.inventory_id
    AND s1.sales_date    = s2.sales_date
    AND s1.sales_quantity = s2.sales_quantity
    AND s1.sales_price   = s2.sales_price
    AND s1._loaded_at    < s2._loaded_at;
