-- =============================================================
-- 00_data_quality_check.sql
-- Data Quality Checks: run BEFORE populate_dimensions/facts
-- Inspect results; no rows = clean; rows = issues to investigate
-- =============================================================

-- -------------------------------------------------------------
-- SECTION 1: NULL / BLANK checks on mandatory key columns
-- -------------------------------------------------------------

-- 1a. stg_beg_inventory: mandatory fields
SELECT 'stg_beg_inventory' AS tbl, 'NULL inventory_id'  AS issue, COUNT(*) AS cnt FROM staging.stg_beg_inventory WHERE inventory_id  IS NULL OR TRIM(inventory_id)  = ''
UNION ALL
SELECT 'stg_beg_inventory', 'NULL store_id',    COUNT(*) FROM staging.stg_beg_inventory WHERE store_id  IS NULL
UNION ALL
SELECT 'stg_beg_inventory', 'NULL brand_id',    COUNT(*) FROM staging.stg_beg_inventory WHERE brand_id  IS NULL
UNION ALL
SELECT 'stg_beg_inventory', 'NULL start_date',  COUNT(*) FROM staging.stg_beg_inventory WHERE start_date IS NULL OR TRIM(start_date) = ''
UNION ALL

-- 1b. stg_end_inventory: mandatory fields
SELECT 'stg_end_inventory', 'NULL inventory_id', COUNT(*) FROM staging.stg_end_inventory WHERE inventory_id IS NULL OR TRIM(inventory_id) = ''
UNION ALL
SELECT 'stg_end_inventory', 'NULL store_id',    COUNT(*) FROM staging.stg_end_inventory WHERE store_id IS NULL
UNION ALL
SELECT 'stg_end_inventory', 'NULL brand_id',    COUNT(*) FROM staging.stg_end_inventory WHERE brand_id IS NULL
UNION ALL
SELECT 'stg_end_inventory', 'NULL end_date',    COUNT(*) FROM staging.stg_end_inventory WHERE end_date IS NULL OR TRIM(end_date) = ''
UNION ALL

-- 1c. stg_sales: mandatory fields
SELECT 'stg_sales', 'NULL inventory_id',  COUNT(*) FROM staging.stg_sales WHERE inventory_id IS NULL OR TRIM(inventory_id) = ''
UNION ALL
SELECT 'stg_sales', 'NULL brand_id',      COUNT(*) FROM staging.stg_sales WHERE brand_id IS NULL
UNION ALL
SELECT 'stg_sales', 'NULL sales_date',    COUNT(*) FROM staging.stg_sales WHERE sales_date IS NULL OR TRIM(sales_date) = ''
UNION ALL
SELECT 'stg_sales', 'NULL sales_quantity',COUNT(*) FROM staging.stg_sales WHERE sales_quantity IS NULL
UNION ALL

-- 1d. stg_purchases: mandatory fields
SELECT 'stg_purchases', 'NULL brand_id',       COUNT(*) FROM staging.stg_purchases WHERE brand_id IS NULL
UNION ALL
SELECT 'stg_purchases', 'NULL po_date',        COUNT(*) FROM staging.stg_purchases WHERE po_date IS NULL OR TRIM(po_date) = ''
UNION ALL
SELECT 'stg_purchases', 'NULL receiving_date', COUNT(*) FROM staging.stg_purchases WHERE receiving_date IS NULL OR TRIM(receiving_date) = ''
UNION ALL

-- 1e. stg_invoice_purchases: mandatory fields
SELECT 'stg_invoice_purchases', 'NULL vendor_number', COUNT(*) FROM staging.stg_invoice_purchases WHERE vendor_number IS NULL
UNION ALL
SELECT 'stg_invoice_purchases', 'NULL po_number',     COUNT(*) FROM staging.stg_invoice_purchases WHERE po_number IS NULL

ORDER BY cnt DESC;


-- -------------------------------------------------------------
-- SECTION 2: Date format validation
-- Check that VARCHAR date strings match expected formats.
-- Expected: YYYY-MM-DD (ISO) or M/D/YYYY (US, sales only)
-- Should return 0 rows if all dates are valid.
-- -------------------------------------------------------------

-- 2a. ISO dates: reject strings that don't match YYYY-MM-DD
SELECT 'stg_beg_inventory.start_date' AS col,
       start_date AS bad_value, COUNT(*) AS cnt
FROM staging.stg_beg_inventory
WHERE start_date !~ '^\d{4}-\d{2}-\d{2}$'
GROUP BY start_date

UNION ALL
SELECT 'stg_end_inventory.end_date', end_date, COUNT(*)
FROM staging.stg_end_inventory
WHERE end_date !~ '^\d{4}-\d{2}-\d{2}$'
GROUP BY end_date

UNION ALL
SELECT 'stg_purchases.po_date', po_date, COUNT(*)
FROM staging.stg_purchases
WHERE po_date !~ '^\d{4}-\d{2}-\d{2}$'
GROUP BY po_date

UNION ALL
SELECT 'stg_purchases.receiving_date', receiving_date, COUNT(*)
FROM staging.stg_purchases
WHERE receiving_date !~ '^\d{4}-\d{2}-\d{2}$'
GROUP BY receiving_date

UNION ALL
SELECT 'stg_purchases.invoice_date', invoice_date, COUNT(*)
FROM staging.stg_purchases
WHERE invoice_date !~ '^\d{4}-\d{2}-\d{2}$'
GROUP BY invoice_date

UNION ALL
SELECT 'stg_purchases.pay_date', pay_date, COUNT(*)
FROM staging.stg_purchases
WHERE pay_date !~ '^\d{4}-\d{2}-\d{2}$'
GROUP BY pay_date

UNION ALL
SELECT 'stg_invoice_purchases.invoice_date', invoice_date, COUNT(*)
FROM staging.stg_invoice_purchases
WHERE invoice_date !~ '^\d{4}-\d{2}-\d{2}$'
GROUP BY invoice_date

UNION ALL
SELECT 'stg_invoice_purchases.po_date', po_date, COUNT(*)
FROM staging.stg_invoice_purchases
WHERE po_date !~ '^\d{4}-\d{2}-\d{2}$'
GROUP BY po_date

UNION ALL
SELECT 'stg_invoice_purchases.pay_date', pay_date, COUNT(*)
FROM staging.stg_invoice_purchases
WHERE pay_date !~ '^\d{4}-\d{2}-\d{2}$'
GROUP BY pay_date

ORDER BY cnt DESC;

-- 2b. US dates (sales): reject strings that don't match M/D/YYYY or MM/DD/YYYY
SELECT 'stg_sales.sales_date' AS col,
       sales_date AS bad_value, COUNT(*) AS cnt
FROM staging.stg_sales
WHERE sales_date !~ '^\d{1,2}/\d{1,2}/\d{4}$'
GROUP BY sales_date
ORDER BY cnt DESC;


-- -------------------------------------------------------------
-- SECTION 3: Logical date range checks
-- All dates should fall within 2015-2017 for this dataset.
-- -------------------------------------------------------------
SELECT 'stg_purchases: receiving < po_date' AS issue,
       COUNT(*) AS cnt
FROM staging.stg_purchases
WHERE receiving_date IS NOT NULL AND po_date IS NOT NULL
  AND TO_DATE(receiving_date, 'YYYY-MM-DD') < TO_DATE(po_date, 'YYYY-MM-DD')

UNION ALL
SELECT 'stg_purchases: lead_time > 180 days',
       COUNT(*)
FROM staging.stg_purchases
WHERE receiving_date IS NOT NULL AND po_date IS NOT NULL
  AND (TO_DATE(receiving_date, 'YYYY-MM-DD') - TO_DATE(po_date, 'YYYY-MM-DD')) > 180

UNION ALL
SELECT 'stg_sales: date outside 2016',
       COUNT(*)
FROM staging.stg_sales
WHERE sales_date IS NOT NULL
  AND TO_DATE(sales_date, 'MM/DD/YYYY') NOT BETWEEN '2016-01-01' AND '2016-12-31'

UNION ALL
SELECT 'stg_beg_inventory: start_date != 2016-01-01',
       COUNT(*)
FROM staging.stg_beg_inventory
WHERE TRIM(start_date) <> '2016-01-01'

UNION ALL
SELECT 'stg_end_inventory: end_date != 2016-12-31',
       COUNT(*)
FROM staging.stg_end_inventory
WHERE TRIM(end_date) <> '2016-12-31'

ORDER BY cnt DESC;


-- -------------------------------------------------------------
-- SECTION 4: Numeric sanity checks
-- -------------------------------------------------------------
SELECT 'stg_sales: negative sales_quantity'  AS issue, COUNT(*) AS cnt FROM staging.stg_sales         WHERE sales_quantity < 0
UNION ALL
SELECT 'stg_sales: negative sales_dollars',          COUNT(*) FROM staging.stg_sales         WHERE sales_dollars  < 0
UNION ALL
SELECT 'stg_sales: zero or negative sales_price',    COUNT(*) FROM staging.stg_sales         WHERE sales_price   <= 0
UNION ALL
SELECT 'stg_purchases: negative quantity',           COUNT(*) FROM staging.stg_purchases     WHERE quantity       < 0
UNION ALL
SELECT 'stg_purchases: negative dollars',            COUNT(*) FROM staging.stg_purchases     WHERE dollars        < 0
UNION ALL
SELECT 'stg_purchases: zero purchase_price',         COUNT(*) FROM staging.stg_purchases     WHERE purchase_price <= 0
UNION ALL
SELECT 'stg_beg_inventory: negative on_hand',        COUNT(*) FROM staging.stg_beg_inventory WHERE on_hand        < 0
UNION ALL
SELECT 'stg_end_inventory: negative on_hand',        COUNT(*) FROM staging.stg_end_inventory WHERE on_hand        < 0
UNION ALL
SELECT 'stg_purchase_prices: price <= 0',            COUNT(*) FROM staging.stg_purchase_prices WHERE price        <= 0
UNION ALL
SELECT 'stg_purchase_prices: purchase_price <= 0',   COUNT(*) FROM staging.stg_purchase_prices WHERE purchase_price <= 0
UNION ALL
SELECT 'stg_purchase_prices: margin inverted (cost>price)', COUNT(*)
FROM staging.stg_purchase_prices
WHERE purchase_price > price
ORDER BY cnt DESC;


-- -------------------------------------------------------------
-- SECTION 5: Referential integrity checks
-- Orphan rows in sales/purchases that won't join to dim_product
-- -------------------------------------------------------------

-- 5a. Sales brands not in purchase_prices (will become NULL cost in facts)
SELECT 'stg_sales: brand_id not in stg_purchase_prices' AS issue,
       s.brand_id,
       COUNT(*) AS sale_rows
FROM staging.stg_sales s
WHERE NOT EXISTS (
    SELECT 1 FROM staging.stg_purchase_prices pp WHERE pp.brand_id = s.brand_id
)
GROUP BY s.brand_id
ORDER BY sale_rows DESC;

-- 5b. Purchases brands not in purchase_prices
SELECT 'stg_purchases: brand_id not in stg_purchase_prices' AS issue,
       p.brand_id,
       COUNT(*) AS purchase_rows
FROM staging.stg_purchases p
WHERE NOT EXISTS (
    SELECT 1 FROM staging.stg_purchase_prices pp WHERE pp.brand_id = p.brand_id
)
GROUP BY p.brand_id
ORDER BY purchase_rows DESC;

-- 5c. Duplicate inventory_id within beg or end inventory
SELECT 'stg_beg_inventory: duplicate inventory_id' AS issue,
       inventory_id, COUNT(*) AS cnt
FROM staging.stg_beg_inventory
GROUP BY inventory_id
HAVING COUNT(*) > 1
ORDER BY cnt DESC;

SELECT 'stg_end_inventory: duplicate inventory_id' AS issue,
       inventory_id, COUNT(*) AS cnt
FROM staging.stg_end_inventory
GROUP BY inventory_id
HAVING COUNT(*) > 1
ORDER BY cnt DESC;


-- -------------------------------------------------------------
-- SECTION 6: Quick row count summary
-- Expected ballpark from full Kaggle dataset:
--   stg_beg_inventory      ~200k
--   stg_end_inventory      ~224k
--   stg_sales              ~9.6M
--   stg_purchases          ~2.4M
--   stg_invoice_purchases  ~6k
--   stg_purchase_prices    ~6k
-- -------------------------------------------------------------
SELECT 'stg_beg_inventory'     AS tbl, COUNT(*) AS rows FROM staging.stg_beg_inventory
UNION ALL
SELECT 'stg_end_inventory',           COUNT(*) FROM staging.stg_end_inventory
UNION ALL
SELECT 'stg_sales',                   COUNT(*) FROM staging.stg_sales
UNION ALL
SELECT 'stg_purchases',               COUNT(*) FROM staging.stg_purchases
UNION ALL
SELECT 'stg_invoice_purchases',       COUNT(*) FROM staging.stg_invoice_purchases
UNION ALL
SELECT 'stg_purchase_prices',         COUNT(*) FROM staging.stg_purchase_prices
ORDER BY tbl;
