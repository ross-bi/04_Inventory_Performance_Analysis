-- =============================================================================
-- Phase 2: Raw Data Validation  
-- Project: 04_Inventory_Performance_Analysis
-- Note: All raw columns are TEXT type — numeric comparisons require CAST
-- =============================================================================

-- ─────────────────────────────────────────────────────────
-- SECTION 1: Row Count Audit
-- ─────────────────────────────────────────────────────────
SELECT 'raw_sales'              AS table_name, COUNT(*) AS row_count FROM raw.raw_sales
UNION ALL
SELECT 'raw_purchases',                         COUNT(*) FROM raw.raw_purchases
UNION ALL
SELECT 'raw_beg_inventory',                     COUNT(*) FROM raw.raw_beg_inventory
UNION ALL
SELECT 'raw_end_inventory',                     COUNT(*) FROM raw.raw_end_inventory
UNION ALL
SELECT 'raw_purchase_prices',                   COUNT(*) FROM raw.raw_purchase_prices
UNION ALL
SELECT 'raw_invoice_purchases',                 COUNT(*) FROM raw.raw_invoice_purchases
ORDER BY table_name;


-- ─────────────────────────────────────────────────────────
-- SECTION 2: NULL / Missing Value Checks
-- ─────────────────────────────────────────────────────────

-- 2a. raw_sales
SELECT
    COUNT(*)                                                    AS total_rows,
    COUNT(*) FILTER (WHERE inventory_id IS NULL)                AS null_inventory_id,
    COUNT(*) FILTER (WHERE sales_date IS NULL)                  AS null_sales_date,
    COUNT(*) FILTER (WHERE sales_quantity IS NULL)              AS null_sales_quantity,
    COUNT(*) FILTER (WHERE sales_dollars IS NULL)               AS null_sales_dollars,
    COUNT(*) FILTER (WHERE vendor_no IS NULL)                   AS null_vendor_no   -- NOTE: vendor_no not vendor_number
FROM raw.raw_sales;

-- 2b. raw_purchases
SELECT
    COUNT(*)                                                    AS total_rows,
    COUNT(*) FILTER (WHERE inventory_id IS NULL)                AS null_inventory_id,
    COUNT(*) FILTER (WHERE po_date IS NULL)                     AS null_po_date,
    COUNT(*) FILTER (WHERE receiving_date IS NULL)              AS null_receiving_date,
    COUNT(*) FILTER (WHERE quantity IS NULL)                    AS null_quantity,
    COUNT(*) FILTER (WHERE dollars IS NULL)                     AS null_dollars,
    COUNT(*) FILTER (WHERE purchase_price IS NULL)              AS null_purchase_price,
    COUNT(*) FILTER (WHERE vendor_number IS NULL)               AS null_vendor_number
FROM raw.raw_purchases;

-- 2c. raw_beg_inventory
SELECT
    COUNT(*)                                                    AS total_rows,
    COUNT(*) FILTER (WHERE inventory_id IS NULL)                AS null_inventory_id,
    COUNT(*) FILTER (WHERE on_hand IS NULL)                     AS null_on_hand,
    COUNT(*) FILTER (WHERE price IS NULL)                       AS null_price,
    COUNT(*) FILTER (WHERE start_date IS NULL)                  AS null_start_date
FROM raw.raw_beg_inventory;

-- 2d. raw_end_inventory
SELECT
    COUNT(*)                                                    AS total_rows,
    COUNT(*) FILTER (WHERE inventory_id IS NULL)                AS null_inventory_id,
    COUNT(*) FILTER (WHERE on_hand IS NULL)                     AS null_on_hand,
    COUNT(*) FILTER (WHERE price IS NULL)                       AS null_price,
    COUNT(*) FILTER (WHERE end_date IS NULL)                    AS null_end_date
FROM raw.raw_end_inventory;

-- 2e. raw_purchase_prices (兩個 price 欄位都要檢查)
SELECT
    COUNT(*)                                                    AS total_rows,
    COUNT(*) FILTER (WHERE brand IS NULL)                       AS null_brand,
    COUNT(*) FILTER (WHERE price IS NULL OR price = '')         AS null_price,
    COUNT(*) FILTER (WHERE purchase_price IS NULL OR purchase_price = '') AS null_purchase_price,
    COUNT(*) FILTER (WHERE vendor_number IS NULL)               AS null_vendor_number
FROM raw.raw_purchase_prices;

-- 2f. raw_invoice_purchases
SELECT
    COUNT(*)                                                    AS total_rows,
    COUNT(*) FILTER (WHERE vendor_number IS NULL)               AS null_vendor_number,
    COUNT(*) FILTER (WHERE invoice_date IS NULL)                AS null_invoice_date,
    COUNT(*) FILTER (WHERE dollars IS NULL)                     AS null_dollars
FROM raw.raw_invoice_purchases;


-- ─────────────────────────────────────────────────────────
-- SECTION 3: Business Rule Checks (with CAST for TEXT)
-- ─────────────────────────────────────────────────────────
SELECT 'raw_sales - negative qty' AS check_name, COUNT(*) AS fail_count
FROM raw.raw_sales
WHERE CAST(sales_quantity AS NUMERIC) <= 0
UNION ALL
SELECT 'raw_sales - negative dollars', COUNT(*)
FROM raw.raw_sales
WHERE CAST(sales_dollars AS NUMERIC) < 0
UNION ALL
-- Price calc: SalesDollars ≠ SalesQuantity × SalesPrice (tolerance $0.02)
SELECT 'raw_sales - price calc mismatch', COUNT(*)
FROM raw.raw_sales
WHERE ABS(CAST(sales_dollars AS NUMERIC)
        - (CAST(sales_quantity AS NUMERIC) * CAST(sales_price AS NUMERIC))) > 0.02
UNION ALL
SELECT 'raw_beg_inventory - negative on_hand', COUNT(*)
FROM raw.raw_beg_inventory
WHERE CAST(on_hand AS NUMERIC) < 0
UNION ALL
SELECT 'raw_end_inventory - negative on_hand', COUNT(*)
FROM raw.raw_end_inventory
WHERE CAST(on_hand AS NUMERIC) < 0
UNION ALL
SELECT 'raw_purchase_prices - zero or null price', COUNT(*)
FROM raw.raw_purchase_prices
WHERE price IS NULL OR price = '' OR CAST(price AS NUMERIC) = 0
UNION ALL
-- purchase_price 與 price 是否存在差異（業務意義核查）
SELECT 'raw_purchase_prices - price vs purchase_price differ', COUNT(*)
FROM raw.raw_purchase_prices
WHERE price IS NOT NULL AND purchase_price IS NOT NULL
  AND price != '' AND purchase_price != ''
  AND CAST(price AS NUMERIC) != CAST(purchase_price AS NUMERIC)
UNION ALL
SELECT 'raw_purchases - dollar calc mismatch', COUNT(*)
FROM raw.raw_purchases
WHERE ABS(CAST(dollars AS NUMERIC)
        - (CAST(purchase_price AS NUMERIC) * CAST(quantity AS NUMERIC))) > 0.02
ORDER BY check_name;


-- ─────────────────────────────────────────────────────────
-- SECTION 4: Date Range Validation
-- ─────────────────────────────────────────────────────────
SELECT
    'raw_sales'  AS table_name,
    MIN(CAST(sales_date AS DATE))   AS min_date,
    MAX(CAST(sales_date AS DATE))   AS max_date,
    COUNT(*) FILTER (WHERE CAST(sales_date AS DATE) < '2016-01-01'
                       OR  CAST(sales_date AS DATE) > '2016-12-31') AS out_of_range
FROM raw.raw_sales
UNION ALL
SELECT
    'raw_purchases',
    MIN(CAST(po_date AS DATE)),
    MAX(CAST(po_date AS DATE)),
    COUNT(*) FILTER (WHERE CAST(po_date AS DATE) < '2015-01-01'
                       OR  CAST(po_date AS DATE) > '2016-12-31')  -- po_date 可跨年
FROM raw.raw_purchases
UNION ALL
SELECT
    'raw_invoice_purchases',
    MIN(CAST(invoice_date AS DATE)),
    MAX(CAST(invoice_date AS DATE)),
    COUNT(*) FILTER (WHERE CAST(invoice_date AS DATE) < '2015-01-01'
                       OR  CAST(invoice_date AS DATE) > '2016-12-31')
FROM raw.raw_invoice_purchases;


-- ─────────────────────────────────────────────────────────
-- SECTION 5: Duplicate Detection
-- ─────────────────────────────────────────────────────────

-- 5a. raw_sales 重複交易
SELECT inventory_id, sales_date, sales_quantity, COUNT(*) AS dup_count
FROM raw.raw_sales
GROUP BY inventory_id, sales_date, sales_quantity
HAVING COUNT(*) > 1
ORDER BY dup_count DESC
LIMIT 20;

-- 5b. raw_purchase_prices 重複 SKU
SELECT brand, description, size, COUNT(*) AS dup_count
FROM raw.raw_purchase_prices
GROUP BY brand, description, size
HAVING COUNT(*) > 1
ORDER BY dup_count DESC
LIMIT 20;


-- ─────────────────────────────────────────────────────────
-- SECTION 6: Referential Integrity
-- ─────────────────────────────────────────────────────────

-- 6a. Sales → Beg Inventory 孤兒檢查
SELECT COUNT(DISTINCT s.inventory_id) AS sales_not_in_beg_inv
FROM raw.raw_sales s
LEFT JOIN raw.raw_beg_inventory b ON s.inventory_id = b.inventory_id
WHERE b.inventory_id IS NULL;

-- 6b. Sales → End Inventory 孤兒檢查
SELECT COUNT(DISTINCT s.inventory_id) AS sales_not_in_end_inv
FROM raw.raw_sales s
LEFT JOIN raw.raw_end_inventory e ON s.inventory_id = e.inventory_id
WHERE e.inventory_id IS NULL;

-- 6c. Purchases vendor → Invoice vendor
SELECT COUNT(DISTINCT p.vendor_number) AS purchase_vendor_not_in_invoice
FROM raw.raw_purchases p
LEFT JOIN raw.raw_invoice_purchases i ON p.vendor_number = i.vendor_number
WHERE i.vendor_number IS NULL;


-- ─────────────────────────────────────────────────────────
-- SECTION 7: VendorName Trailing Whitespace
-- ─────────────────────────────────────────────────────────
SELECT
    vendor_name,
    LENGTH(vendor_name)        AS raw_len,
    LENGTH(TRIM(vendor_name))  AS trimmed_len
FROM raw.raw_sales
WHERE LENGTH(vendor_name) != LENGTH(TRIM(vendor_name))
GROUP BY vendor_name
ORDER BY raw_len DESC
LIMIT 20;