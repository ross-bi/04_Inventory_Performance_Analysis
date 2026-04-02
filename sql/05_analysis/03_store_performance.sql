-- =============================================================
-- 03_store_performance.sql
-- Analysis: Store-Level Inventory Performance Scorecard
--
-- Combines all KPIs at store level for Power BI store comparison page
-- =============================================================

CREATE OR REPLACE VIEW warehouse.vw_analysis_store_scorecard AS
WITH store_sales AS (
    SELECT
        ds.store_id,
        ds.city,
        SUM(fs.sales_dollars)  AS total_revenue,
        SUM(fs.cogs)           AS total_cogs,
        SUM(fs.gross_profit)   AS total_gross_profit,
        SUM(fs.sales_quantity) AS total_qty_sold
    FROM warehouse.fact_sales fs
    JOIN warehouse.dim_store ds ON ds.store_key = fs.store_key
    GROUP BY ds.store_id, ds.city
),
store_inv AS (
    SELECT
        ds.store_id,
        SUM(CASE WHEN fis.snapshot_type = 'BEG' THEN fis.on_hand_cost ELSE 0 END) AS beg_inv_cost,
        SUM(CASE WHEN fis.snapshot_type = 'END' THEN fis.on_hand_cost ELSE 0 END) AS end_inv_cost,
        SUM(CASE WHEN fis.snapshot_type = 'END' THEN fis.on_hand_qty  ELSE 0 END) AS end_on_hand_total
    FROM warehouse.fact_inventory_snapshot fis
    JOIN warehouse.dim_store ds ON ds.store_key = fis.store_key
    GROUP BY ds.store_id
),
store_stockout AS (
    SELECT store_id, stockout_rate_pct
    FROM warehouse.vw_kpi_stockout_rate_summary
),
store_overstock AS (
    SELECT store_id, overstock_pct, total_excess_cost
    FROM warehouse.vw_kpi_overstock_summary
)
SELECT
    ss.store_id,
    ss.city,
    ss.total_revenue,
    ss.total_cogs,
    ROUND(100.0 * ss.total_gross_profit / NULLIF(ss.total_revenue, 0), 2) AS gross_margin_pct,
    ss.total_qty_sold,
    si.beg_inv_cost,
    si.end_inv_cost,
    ROUND((si.beg_inv_cost + si.end_inv_cost) / 2.0, 2)               AS avg_inv_cost,
    -- Inventory Turnover at store level
    ROUND(
        ss.total_cogs / NULLIF((si.beg_inv_cost + si.end_inv_cost) / 2.0, 0),
        4
    )                                                                  AS inventory_turnover,
    -- DSI at store level
    ROUND(
        365.0 / NULLIF(
            ss.total_cogs / NULLIF((si.beg_inv_cost + si.end_inv_cost) / 2.0, 0), 0
        ), 1
    )                                                                  AS dsi_days,
    so.stockout_rate_pct,
    sov.overstock_pct,
    sov.total_excess_cost
FROM store_sales ss
JOIN store_inv          si  ON si.store_id  = ss.store_id
LEFT JOIN store_stockout so  ON so.store_id  = ss.store_id
LEFT JOIN store_overstock sov ON sov.store_id = ss.store_id
ORDER BY ss.total_revenue DESC;
