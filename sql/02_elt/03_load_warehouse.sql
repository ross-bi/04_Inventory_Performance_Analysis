-- ============================================================
-- FILE: sql/02_elt/03_load_warehouse.sql
-- PURPOSE: Layer 3 - Build Star Schema from Staging
-- RUN AFTER: 02_transform_staging.sql
-- ============================================================

-- ============================================================
-- dim_date  (generated from sales date range)
-- ============================================================
TRUNCATE TABLE warehouse.dim_date;
INSERT INTO warehouse.dim_date
SELECT DISTINCT
    sales_date                                              AS date_key,
    EXTRACT(YEAR    FROM sales_date)::SMALLINT              AS year,
    EXTRACT(QUARTER FROM sales_date)::SMALLINT              AS quarter,
    EXTRACT(MONTH   FROM sales_date)::SMALLINT              AS month,
    TO_CHAR(sales_date, 'Month')                            AS month_name,
    EXTRACT(WEEK    FROM sales_date)::SMALLINT              AS week,
    EXTRACT(DOW     FROM sales_date)::SMALLINT              AS day_of_week,
    EXTRACT(DOW     FROM sales_date) IN (0, 6)              AS is_weekend
FROM staging.stg_sales
WHERE dq_flag = 'VALID'
ON CONFLICT (date_key) DO NOTHING;

-- ============================================================
-- dim_product  (from sales; enriched with purchase_prices)
-- ============================================================
TRUNCATE TABLE warehouse.dim_product;
INSERT INTO warehouse.dim_product
SELECT DISTINCT ON (brand_id)
    brand_id,
    description,
    size_std                                                AS size,
    volume                                                  AS volume_ml,
    classification                                          AS class_id,
    class_name
FROM staging.stg_sales
WHERE dq_flag = 'VALID'
ORDER BY brand_id, _loaded_at DESC
ON CONFLICT (brand_id) DO UPDATE
    SET description = EXCLUDED.description,
        size        = EXCLUDED.size,
        class_name  = EXCLUDED.class_name;

-- ============================================================
-- dim_store
-- ============================================================
TRUNCATE TABLE warehouse.dim_store;
INSERT INTO warehouse.dim_store
SELECT DISTINCT
    store_id,
    store_name
FROM staging.stg_sales
WHERE dq_flag = 'VALID'
ON CONFLICT (store_id) DO NOTHING;

-- ============================================================
-- dim_vendor  (union sales + purchases for completeness)
-- ============================================================
TRUNCATE TABLE warehouse.dim_vendor;
INSERT INTO warehouse.dim_vendor
SELECT DISTINCT ON (vendor_id)
    vendor_id,
    vendor_name_clean AS vendor_name
FROM staging.stg_purchases
WHERE dq_flag = 'VALID'
ORDER BY vendor_id, _loaded_at DESC
ON CONFLICT (vendor_id) DO NOTHING;

-- ============================================================
-- fact_inventory
-- Grain: brand_id x store_id x sale_year x sale_month
-- ============================================================
TRUNCATE TABLE warehouse.fact_inventory;
INSERT INTO warehouse.fact_inventory (
    brand_id, store_id, sale_year, sale_month,
    total_sales_qty, total_sales_dollars, total_excise_tax, selling_days,
    total_purchase_qty, total_purchase_dollars,
    beg_inventory, end_inventory, avg_inventory,
    inventory_turnover, dsi
)
WITH
-- 1. Aggregate Sales by SKU x Store x Month
sales_agg AS (
    SELECT
        brand_id,
        store_id,
        sale_year,
        sale_month,
        SUM(sales_quantity)                                 AS total_sales_qty,
        SUM(sales_dollars)                                  AS total_sales_dollars,
        SUM(excise_tax)                                     AS total_excise_tax,
        COUNT(DISTINCT sales_date)                          AS selling_days
    FROM staging.stg_sales
    WHERE dq_flag = 'VALID'
    GROUP BY brand_id, store_id, sale_year, sale_month
),
-- 2. Aggregate Purchases by SKU x Store x Month (using invoice_date)
purchases_agg AS (
    SELECT
        brand_id,
        store_id,
        EXTRACT(YEAR  FROM invoice_date)::SMALLINT          AS pur_year,
        EXTRACT(MONTH FROM invoice_date)::SMALLINT          AS pur_month,
        SUM(quantity)                                       AS total_purchase_qty,
        SUM(dollars)                                        AS total_purchase_dollars
    FROM staging.stg_purchases
    WHERE dq_flag = 'VALID'
    GROUP BY brand_id, store_id, pur_year, pur_month
),
-- 3. Pivot beg/end inventory snapshot per SKU x Store
inv_snap AS (
    SELECT
        brand_id,
        store,
        MAX(CASE WHEN snapshot_type = 'BEG' THEN on_hand END)  AS beg_inventory,
        MAX(CASE WHEN snapshot_type = 'END' THEN on_hand END)  AS end_inventory
    FROM staging.stg_inventory_snapshot
    WHERE dq_flag = 'VALID'
    GROUP BY brand_id, store
)
SELECT
    s.brand_id,
    s.store_id,
    s.sale_year,
    s.sale_month,
    s.total_sales_qty,
    s.total_sales_dollars,
    s.total_excise_tax,
    s.selling_days,
    COALESCE(p.total_purchase_qty,      0)                  AS total_purchase_qty,
    COALESCE(p.total_purchase_dollars,  0)                  AS total_purchase_dollars,
    COALESCE(i.beg_inventory,           0)                  AS beg_inventory,
    COALESCE(i.end_inventory,           0)                  AS end_inventory,
    -- avg_inventory = (beg + end) / 2
    ROUND(
        (COALESCE(i.beg_inventory, 0) + COALESCE(i.end_inventory, 0)) / 2.0
    , 2)                                                    AS avg_inventory,
    -- Inventory Turnover = Sales Qty / Avg Inventory
    CASE
        WHEN (COALESCE(i.beg_inventory,0) + COALESCE(i.end_inventory,0)) > 0
        THEN ROUND(
            s.total_sales_qty::NUMERIC /
            NULLIF((COALESCE(i.beg_inventory,0) + COALESCE(i.end_inventory,0)) / 2.0, 0)
        , 4)
        ELSE NULL
    END                                                     AS inventory_turnover,
    -- DSI = (Avg Inventory / Annual Sales Qty) * 365
    CASE
        WHEN s.total_sales_qty > 0
        THEN ROUND(
            ((COALESCE(i.beg_inventory,0) + COALESCE(i.end_inventory,0)) / 2.0)
            / (s.total_sales_qty::NUMERIC / 365.0)
        , 1)
        ELSE NULL
    END                                                     AS dsi
FROM sales_agg s
LEFT JOIN purchases_agg p
    ON  s.brand_id   = p.brand_id
    AND s.store_id   = p.store_id
    AND s.sale_year  = p.pur_year
    AND s.sale_month = p.pur_month
LEFT JOIN inv_snap i
    ON  s.brand_id = i.brand_id
    AND s.store_id = i.store;
