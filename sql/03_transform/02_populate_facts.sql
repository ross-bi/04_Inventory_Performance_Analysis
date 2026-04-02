-- =============================================================
-- 02_populate_facts.sql
-- Populates all three fact tables from staging
-- Run AFTER 01_populate_dimensions.sql
-- =============================================================

-- ------------------------------------------------------------
-- fact_inventory_snapshot  (BEG + END)
-- ------------------------------------------------------------
INSERT INTO warehouse.fact_inventory_snapshot (
    snapshot_date_key, product_key, store_key,
    on_hand_qty, on_hand_cost, on_hand_retail, snapshot_type
)
-- Beginning inventory
SELECT
    TO_CHAR(b.start_date, 'YYYYMMDD')::INT   AS snapshot_date_key,
    dp.product_key,
    ds.store_key,
    b.on_hand                                AS on_hand_qty,
    b.on_hand * COALESCE(dp.purchase_price, 0) AS on_hand_cost,
    b.on_hand * COALESCE(dp.retail_price, b.price, 0) AS on_hand_retail,
    'BEG'                                    AS snapshot_type
FROM staging.stg_beg_inventory b
JOIN warehouse.dim_product dp ON dp.brand_id = b.brand_id
JOIN warehouse.dim_store   ds ON ds.store_id  = b.store_id

UNION ALL

-- Ending inventory
SELECT
    TO_CHAR(e.end_date, 'YYYYMMDD')::INT     AS snapshot_date_key,
    dp.product_key,
    ds.store_key,
    e.on_hand                                AS on_hand_qty,
    e.on_hand * COALESCE(dp.purchase_price, 0) AS on_hand_cost,
    e.on_hand * COALESCE(dp.retail_price, e.price, 0) AS on_hand_retail,
    'END'                                    AS snapshot_type
FROM staging.stg_end_inventory e
JOIN warehouse.dim_product dp ON dp.brand_id = e.brand_id
JOIN warehouse.dim_store   ds ON ds.store_id  = e.store_id;

-- ------------------------------------------------------------
-- fact_purchases
-- ------------------------------------------------------------
INSERT INTO warehouse.fact_purchases (
    po_date_key, receiving_date_key,
    product_key, store_key, vendor_key,
    po_number, quantity, dollars, lead_time_days
)
SELECT
    TO_CHAR(p.po_date,        'YYYYMMDD')::INT   AS po_date_key,
    TO_CHAR(p.receiving_date, 'YYYYMMDD')::INT   AS receiving_date_key,
    dp.product_key,
    ds.store_key,
    dv.vendor_key,
    p.po_number,
    p.quantity,
    p.dollars,
    CASE
        WHEN p.receiving_date >= p.po_date
        THEN (p.receiving_date - p.po_date)
        ELSE NULL
    END                                           AS lead_time_days
FROM staging.stg_purchases p
JOIN warehouse.dim_product dp ON dp.brand_id    = p.brand_id
JOIN warehouse.dim_store   ds ON ds.store_id    = p.store_id
LEFT JOIN warehouse.dim_vendor dv ON dv.vendor_number = p.vendor_number;

-- ------------------------------------------------------------
-- fact_sales
-- ------------------------------------------------------------
INSERT INTO warehouse.fact_sales (
    date_key, product_key, store_key, vendor_key,
    sales_quantity, sales_dollars, sales_price, excise_tax,
    cogs, gross_profit
)
SELECT
    TO_CHAR(s.sales_date, 'YYYYMMDD')::INT   AS date_key,
    dp.product_key,
    ds.store_key,
    dv.vendor_key,
    s.sales_quantity,
    s.sales_dollars,
    s.sales_price,
    s.excise_tax,
    ROUND(s.sales_quantity * COALESCE(dp.purchase_price, 0), 2) AS cogs,
    ROUND(s.sales_dollars  - (s.sales_quantity * COALESCE(dp.purchase_price, 0)), 2) AS gross_profit
FROM staging.stg_sales s
JOIN warehouse.dim_product dp ON dp.brand_id  = s.brand_id
JOIN warehouse.dim_store   ds ON ds.store_id  = s.store_id
LEFT JOIN warehouse.dim_vendor dv ON dv.vendor_number = s.vendor_no;

-- Row count check
SELECT 'fact_sales'              AS fact, COUNT(*) FROM warehouse.fact_sales
UNION ALL
SELECT 'fact_purchases',                  COUNT(*) FROM warehouse.fact_purchases
UNION ALL
SELECT 'fact_inventory_snapshot',         COUNT(*) FROM warehouse.fact_inventory_snapshot;
