-- ============================================================
-- FILE: sql/04_analysis/01_kpi_views.sql
-- PURPOSE: KPI Analytical Views for Power BI
-- KPIs: Inventory Turnover, DSI, Stockout Rate,
--       Overstock %, Reorder Point
-- ============================================================

-- ============================================================
-- VIEW 1: vw_inventory_turnover
-- KPIs: Inventory Turnover, DSI
-- ============================================================
DROP VIEW IF EXISTS warehouse.vw_inventory_turnover;
CREATE VIEW warehouse.vw_inventory_turnover AS
SELECT
    f.fact_id,
    p.brand_id,
    p.description                           AS product_name,
    p.class_name                            AS category,
    p.size,
    s.store_id,
    s.store_name,
    f.sale_year,
    f.sale_month,
    f.beg_inventory,
    f.end_inventory,
    f.avg_inventory,
    f.total_sales_qty,
    f.total_sales_dollars,
    f.total_purchase_qty,
    -- KPIs
    f.inventory_turnover,
    f.dsi,
    -- Turnover health classification
    CASE
        WHEN f.inventory_turnover >= 12  THEN 'High (Fast Moving)'
        WHEN f.inventory_turnover >= 4   THEN 'Normal'
        WHEN f.inventory_turnover >= 1   THEN 'Slow Moving'
        ELSE                                  'Dead Stock'
    END                                     AS turnover_health
FROM warehouse.fact_inventory f
JOIN warehouse.dim_product p ON f.brand_id = p.brand_id
JOIN warehouse.dim_store   s ON f.store_id = s.store_id;

-- ============================================================
-- VIEW 2: vw_stockout_analysis
-- KPI: Stockout Rate
-- Stockout = end_inventory = 0 AND there were sales in the period
-- ============================================================
DROP VIEW IF EXISTS warehouse.vw_stockout_analysis;
CREATE VIEW warehouse.vw_stockout_analysis AS
SELECT
    p.brand_id,
    p.description                           AS product_name,
    p.class_name                            AS category,
    s.store_id,
    s.store_name,
    f.sale_year,
    f.sale_month,
    f.total_sales_qty,
    f.end_inventory,
    -- Stockout Flag
    CASE
        WHEN f.end_inventory = 0 AND f.total_sales_qty > 0 THEN 'STOCKOUT'
        WHEN f.end_inventory = 0 AND f.total_sales_qty = 0 THEN 'ZERO_NO_SALES'
        ELSE 'IN_STOCK'
    END                                     AS stockout_flag,
    -- Lost revenue estimate (avg daily sales * days out of stock approximation)
    CASE
        WHEN f.end_inventory = 0 AND f.total_sales_qty > 0
        THEN ROUND((f.total_sales_dollars / NULLIF(f.selling_days, 0)) * 7, 2)
        ELSE 0
    END                                     AS est_lost_revenue_7d
FROM warehouse.fact_inventory f
JOIN warehouse.dim_product p ON f.brand_id = p.brand_id
JOIN warehouse.dim_store   s ON f.store_id = s.store_id;

-- ============================================================
-- VIEW 3: vw_overstock_analysis
-- KPI: Overstock %
-- Overstock = end_inventory > (3 * avg monthly sales qty)
-- months_of_supply = end_inventory / avg_monthly_sales
-- ============================================================
DROP VIEW IF EXISTS warehouse.vw_overstock_analysis;
CREATE VIEW warehouse.vw_overstock_analysis AS
SELECT
    p.brand_id,
    p.description                               AS product_name,
    p.class_name                                AS category,
    s.store_id,
    s.store_name,
    f.sale_year,
    f.sale_month,
    f.end_inventory,
    f.total_sales_qty                           AS monthly_sales_qty,
    -- Months of Supply
    ROUND(
        f.end_inventory::NUMERIC / NULLIF(f.total_sales_qty, 0)
    , 1)                                        AS months_of_supply,
    -- Overstock Flag (>3 months of supply = overstock)
    CASE
        WHEN f.total_sales_qty = 0 AND f.end_inventory > 0
            THEN 'DEAD_STOCK'
        WHEN f.end_inventory > 3 * NULLIF(f.total_sales_qty, 0)
            THEN 'OVERSTOCK'
        WHEN f.end_inventory > 1.5 * NULLIF(f.total_sales_qty, 0)
            THEN 'EXCESS'
        ELSE 'NORMAL'
    END                                         AS overstock_flag,
    -- Estimated overstock value (excess units * retail price proxy)
    CASE
        WHEN f.end_inventory > 3 * NULLIF(f.total_sales_qty, 0)
        THEN ROUND(
            (f.end_inventory - 3 * f.total_sales_qty)::NUMERIC
            * (f.total_sales_dollars / NULLIF(f.total_sales_qty, 0))
        , 2)
        ELSE 0
    END                                         AS est_overstock_value
FROM warehouse.fact_inventory f
JOIN warehouse.dim_product p ON f.brand_id = p.brand_id
JOIN warehouse.dim_store   s ON f.store_id = s.store_id;

-- ============================================================
-- VIEW 4: vw_reorder_point
-- KPI: Reorder Point
-- Formula:
--   avg_daily_sales  = total_sales_qty / 365
--   reorder_point    = avg_daily_sales * lead_time_days (default 7)
--   safety_stock     = avg_daily_sales * 2 * lead_time_days
-- ============================================================
DROP VIEW IF EXISTS warehouse.vw_reorder_point;
CREATE VIEW warehouse.vw_reorder_point AS
SELECT
    p.brand_id,
    p.description                                       AS product_name,
    p.class_name                                        AS category,
    s.store_id,
    s.store_name,
    f.sale_year,
    f.end_inventory                                     AS current_stock,
    f.total_sales_qty                                   AS annual_sales_qty,
    -- Avg daily sales
    ROUND(f.total_sales_qty::NUMERIC / 365.0, 3)        AS avg_daily_sales,
    -- Reorder Point (lead time = 7 days)
    ROUND((f.total_sales_qty::NUMERIC / 365.0) * 7, 0) AS reorder_point,
    -- Safety Stock (2x lead time)
    ROUND((f.total_sales_qty::NUMERIC / 365.0) * 14, 0) AS safety_stock_qty,
    -- Replenishment Recommendation
    CASE
        WHEN f.end_inventory <= ROUND((f.total_sales_qty::NUMERIC / 365.0) * 7, 0)
            THEN 'REORDER_NOW'
        WHEN f.end_inventory <= ROUND((f.total_sales_qty::NUMERIC / 365.0) * 14, 0)
            THEN 'REORDER_SOON'
        ELSE 'SUFFICIENT'
    END                                                 AS reorder_flag,
    -- Suggested order quantity (EOQ proxy: 30-day supply - current stock)
    GREATEST(
        0,
        ROUND((f.total_sales_qty::NUMERIC / 365.0) * 30, 0) - f.end_inventory
    )                                                   AS suggested_order_qty
FROM warehouse.fact_inventory f
JOIN warehouse.dim_product p ON f.brand_id = p.brand_id
JOIN warehouse.dim_store   s ON f.store_id = s.store_id
WHERE f.total_sales_qty > 0;

-- ============================================================
-- VIEW 5: vw_kpi_summary  (Power BI Executive Dashboard)
-- Aggregate KPIs at brand x category level
-- ============================================================
DROP VIEW IF EXISTS warehouse.vw_kpi_summary;
CREATE VIEW warehouse.vw_kpi_summary AS
SELECT
    p.class_name                                            AS category,
    f.sale_year,
    f.sale_month,
    COUNT(DISTINCT f.brand_id)                              AS sku_count,
    SUM(f.total_sales_qty)                                  AS total_sales_qty,
    SUM(f.total_sales_dollars)                              AS total_sales_dollars,
    SUM(f.total_purchase_qty)                               AS total_purchase_qty,
    ROUND(AVG(f.inventory_turnover), 2)                     AS avg_turnover,
    ROUND(AVG(f.dsi), 1)                                    AS avg_dsi,
    -- Stockout Rate = stockout SKUs / total SKUs
    ROUND(
        SUM(CASE WHEN f.end_inventory = 0 AND f.total_sales_qty > 0 THEN 1 ELSE 0 END)::NUMERIC
        / NULLIF(COUNT(*), 0) * 100
    , 2)                                                    AS stockout_rate_pct,
    -- Overstock Rate
    ROUND(
        SUM(CASE WHEN f.end_inventory > 3 * f.total_sales_qty THEN 1 ELSE 0 END)::NUMERIC
        / NULLIF(COUNT(*), 0) * 100
    , 2)                                                    AS overstock_rate_pct
FROM warehouse.fact_inventory f
JOIN warehouse.dim_product p ON f.brand_id = p.brand_id
GROUP BY p.class_name, f.sale_year, f.sale_month
ORDER BY f.sale_year, f.sale_month, category;
