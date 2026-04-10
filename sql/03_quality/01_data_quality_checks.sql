-- ============================================================
-- FILE: sql/03_quality/01_data_quality_checks.sql
-- PURPOSE: Data Quality Audit Report
-- RUN AFTER: 02_transform_staging.sql
-- ============================================================

-- ============================================================
-- SECTION 1: DQ Flag Summary per Table
-- ============================================================

-- Sales DQ Summary
SELECT
    'stg_sales'         AS source_table,
    dq_flag,
    COUNT(*)            AS row_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pct
FROM staging.stg_sales
GROUP BY dq_flag
ORDER BY row_count DESC;

-- Purchases DQ Summary
SELECT
    'stg_purchases'     AS source_table,
    dq_flag,
    COUNT(*)            AS row_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pct
FROM staging.stg_purchases
GROUP BY dq_flag
ORDER BY row_count DESC;

-- Inventory Snapshot DQ Summary
SELECT
    'stg_inventory_snapshot' AS source_table,
    dq_flag,
    COUNT(*),
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pct
FROM staging.stg_inventory_snapshot
GROUP BY dq_flag
ORDER BY dq_flag;

-- ============================================================
-- SECTION 2: Amount Mismatch Detail (Sales)
-- sales_dollars should equal sales_price * sales_quantity
-- ============================================================
SELECT
    inventory_id,
    sales_date,
    sales_quantity,
    sales_price,
    sales_dollars,
    ROUND(sales_price * sales_quantity, 2)      AS expected_dollars,
    ABS(sales_dollars - sales_price * sales_quantity) AS discrepancy
FROM staging.stg_sales
WHERE dq_flag = 'AMOUNT_MISMATCH'
ORDER BY discrepancy DESC
LIMIT 50;

-- ============================================================
-- SECTION 3: Amount Mismatch Detail (Purchases)
-- ============================================================
SELECT
    inventory_id,
    invoice_date,
    quantity,
    purchase_price,
    dollars,
    ROUND(purchase_price * quantity, 2)         AS expected_dollars,
    ABS(dollars - purchase_price * quantity)    AS discrepancy
FROM staging.stg_purchases
WHERE dq_flag = 'AMOUNT_MISMATCH'
ORDER BY discrepancy DESC
LIMIT 50;

-- ============================================================
-- SECTION 4: Inventory Orphan Check
-- SKUs in beg/end inventory with NO sales records
-- (Potential dead stock / slow movers)
-- ============================================================
SELECT
    i.inventory_id,
    i.brand_id,
    i.description,
    i.snapshot_type,
    i.on_hand,
    i.snapshot_date
FROM staging.stg_inventory_snapshot i
LEFT JOIN staging.stg_sales s
    ON i.brand_id = s.brand_id
    AND i.store   = s.store
WHERE s.brand_id IS NULL
  AND i.on_hand > 0
ORDER BY i.on_hand DESC
LIMIT 100;

-- ============================================================
-- SECTION 5: Negative / Zero On-Hand Inventory
-- ============================================================
SELECT
    inventory_id,
    store,
    brand_id,
    description,
    snapshot_type,
    on_hand,
    snapshot_date
FROM staging.stg_inventory_snapshot
WHERE on_hand <= 0
ORDER BY on_hand ASC;

-- ============================================================
-- SECTION 6: Duplicate Sales Transactions Check
-- (same inventory_id + date + qty + price)
-- ============================================================
SELECT
    inventory_id,
    sales_date,
    sales_quantity,
    sales_price,
    COUNT(*) AS duplicate_count
FROM staging.stg_sales
GROUP BY inventory_id, sales_date, sales_quantity, sales_price
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC
LIMIT 50;

-- ============================================================
-- SECTION 7: PO Date Anomalies (receiving before PO)
-- ============================================================
SELECT
    inventory_id,
    po_number,
    po_date,
    receiving_date,
    (receiving_date - po_date) AS days_diff
FROM staging.stg_purchases
WHERE dq_flag = 'RECEIVING_BEFORE_PO'
ORDER BY days_diff ASC;

-- ============================================================
-- SECTION 8: Raw vs Staging Row Count Reconciliation
-- ============================================================
SELECT 'raw.sales'                 AS layer, COUNT(*) AS rows FROM raw.sales
UNION ALL
SELECT 'staging.stg_sales',                  COUNT(*) FROM staging.stg_sales
UNION ALL
SELECT 'raw.purchases',                      COUNT(*) FROM raw.purchases
UNION ALL
SELECT 'staging.stg_purchases',              COUNT(*) FROM staging.stg_purchases
UNION ALL
SELECT 'raw.beg_inventory + raw.end_inventory',
    (SELECT COUNT(*) FROM raw.beg_inventory) + (SELECT COUNT(*) FROM raw.end_inventory)
UNION ALL
SELECT 'staging.stg_inventory_snapshot',     COUNT(*) FROM staging.stg_inventory_snapshot
ORDER BY layer;
