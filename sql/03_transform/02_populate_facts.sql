-- =============================================================
-- 02_populate_facts.sql
-- Populates all three fact tables from staging.
-- Run AFTER 01_populate_dimensions.sql
--
-- DATE CONVERSION REFERENCE:
--   stg_beg_inventory.start_date   VARCHAR  YYYY-MM-DD  -> TO_DATE(x, 'YYYY-MM-DD')
--   stg_end_inventory.end_date     VARCHAR  YYYY-MM-DD  -> TO_DATE(x, 'YYYY-MM-DD')
--   stg_sales.sales_date           VARCHAR  M/D/YYYY    -> TO_DATE(x, 'MM/DD/YYYY')
--   stg_purchases.po_date          VARCHAR  YYYY-MM-DD  -> TO_DATE(x, 'YYYY-MM-DD')
--   stg_purchases.receiving_date   VARCHAR  YYYY-MM-DD  -> TO_DATE(x, 'YYYY-MM-DD')
--   stg_purchases.invoice_date     VARCHAR  YYYY-MM-DD  -> TO_DATE(x, 'YYYY-MM-DD')
--   stg_purchases.pay_date         VARCHAR  YYYY-MM-DD  -> TO_DATE(x, 'YYYY-MM-DD')
--   stg_invoice_purchases.*_date   VARCHAR  YYYY-MM-DD  -> TO_DATE(x, 'YYYY-MM-DD')
--
--   date_key helper: TO_CHAR(TO_DATE(x, fmt), 'YYYYMMDD')::INT
-- =============================================================

-- ============================================================
-- HELPER: inline date-key conversion macros (used as comments)
-- ISO dates  : TO_CHAR(TO_DATE(col, 'YYYY-MM-DD'), 'YYYYMMDD')::INT
-- US  dates  : TO_CHAR(TO_DATE(col, 'MM/DD/YYYY'), 'YYYYMMDD')::INT
-- ============================================================

-- ------------------------------------------------------------
-- fact_inventory_snapshot  (BEG + END)
-- Both snapshot files use YYYY-MM-DD format.
-- ------------------------------------------------------------
INSERT INTO warehouse.fact_inventory_snapshot (
    snapshot_date_key, product_key, store_key,
    on_hand_qty, on_hand_cost, on_hand_retail, snapshot_type
)
-- Beginning inventory
SELECT
    TO_CHAR(TO_DATE(b.start_date, 'YYYY-MM-DD'), 'YYYYMMDD')::INT  AS snapshot_date_key,
    dp.product_key,
    ds.store_key,
    b.on_hand                                                       AS on_hand_qty,
    b.on_hand * COALESCE(dp.purchase_price, 0)                      AS on_hand_cost,
    b.on_hand * COALESCE(dp.retail_price, b.price, 0)               AS on_hand_retail,
    'BEG'                                                           AS snapshot_type
FROM staging.stg_beg_inventory b
JOIN warehouse.dim_product dp ON dp.brand_id = b.brand_id
JOIN warehouse.dim_store   ds ON ds.store_id  = b.store_id

UNION ALL

-- Ending inventory
SELECT
    TO_CHAR(TO_DATE(e.end_date, 'YYYY-MM-DD'), 'YYYYMMDD')::INT    AS snapshot_date_key,
    dp.product_key,
    ds.store_key,
    e.on_hand                                                       AS on_hand_qty,
    e.on_hand * COALESCE(dp.purchase_price, 0)                      AS on_hand_cost,
    e.on_hand * COALESCE(dp.retail_price, e.price, 0)               AS on_hand_retail,
    'END'                                                           AS snapshot_type
FROM staging.stg_end_inventory e
JOIN warehouse.dim_product dp ON dp.brand_id = e.brand_id
JOIN warehouse.dim_store   ds ON ds.store_id  = e.store_id;

-- ------------------------------------------------------------
-- fact_purchases
-- All date columns in stg_purchases use YYYY-MM-DD format.
-- lead_time_days = receiving_date - po_date (DATE arithmetic)
-- ------------------------------------------------------------
INSERT INTO warehouse.fact_purchases (
    po_date_key, receiving_date_key,
    product_key, store_key, vendor_key,
    po_number, quantity, dollars, lead_time_days
)
SELECT
    TO_CHAR(TO_DATE(p.po_date,        'YYYY-MM-DD'), 'YYYYMMDD')::INT  AS po_date_key,
    TO_CHAR(TO_DATE(p.receiving_date, 'YYYY-MM-DD'), 'YYYYMMDD')::INT  AS receiving_date_key,
    dp.product_key,
    ds.store_key,
    dv.vendor_key,
    p.po_number,
    p.quantity,
    p.dollars,
    CASE
        WHEN p.receiving_date IS NOT NULL AND p.po_date IS NOT NULL
          AND TO_DATE(p.receiving_date, 'YYYY-MM-DD')
              >= TO_DATE(p.po_date, 'YYYY-MM-DD')
        THEN TO_DATE(p.receiving_date, 'YYYY-MM-DD')
           - TO_DATE(p.po_date,        'YYYY-MM-DD')
        ELSE NULL
    END                                                                 AS lead_time_days
FROM staging.stg_purchases p
JOIN warehouse.dim_product dp ON dp.brand_id      = p.brand_id
JOIN warehouse.dim_store   ds ON ds.store_id       = p.store_id
LEFT JOIN warehouse.dim_vendor dv ON dv.vendor_number = p.vendor_number;

-- ------------------------------------------------------------
-- fact_sales
-- sales_date uses M/D/YYYY format (US style, e.g. 1/15/2016).
-- Use TO_DATE(sales_date, 'MM/DD/YYYY') for conversion.
-- ------------------------------------------------------------
INSERT INTO warehouse.fact_sales (
    date_key, product_key, store_key, vendor_key,
    sales_quantity, sales_dollars, sales_price, excise_tax,
    cogs, gross_profit
)
SELECT
    TO_CHAR(TO_DATE(s.sales_date, 'MM/DD/YYYY'), 'YYYYMMDD')::INT  AS date_key,
    dp.product_key,
    ds.store_key,
    dv.vendor_key,
    s.sales_quantity,
    s.sales_dollars,
    s.sales_price,
    s.excise_tax,
    ROUND(s.sales_quantity * COALESCE(dp.purchase_price, 0), 2)    AS cogs,
    ROUND(
        s.sales_dollars
        - (s.sales_quantity * COALESCE(dp.purchase_price, 0)), 2
    )                                                               AS gross_profit
FROM staging.stg_sales s
JOIN warehouse.dim_product dp ON dp.brand_id      = s.brand_id
JOIN warehouse.dim_store   ds ON ds.store_id       = s.store_id
LEFT JOIN warehouse.dim_vendor dv ON dv.vendor_number = s.vendor_no;

-- ------------------------------------------------------------
-- Row count check
-- ------------------------------------------------------------
SELECT 'fact_sales'               AS fact, COUNT(*) AS rows FROM warehouse.fact_sales
UNION ALL
SELECT 'fact_purchases',                   COUNT(*) FROM warehouse.fact_purchases
UNION ALL
SELECT 'fact_inventory_snapshot',          COUNT(*) FROM warehouse.fact_inventory_snapshot;
