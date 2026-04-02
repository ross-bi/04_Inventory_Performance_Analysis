-- =============================================================
-- 01_inventory_turnover.sql
-- KPI: Inventory Turnover & DSI (Days Sales of Inventory)
--
-- Formula:
--   Inventory Turnover = Total COGS / Avg Inventory Cost
--   DSI = 365 / Inventory Turnover
--
-- Avg Inventory Cost = (BEG on_hand_cost + END on_hand_cost) / 2
-- =============================================================

CREATE OR REPLACE VIEW warehouse.vw_kpi_inventory_turnover AS
WITH cogs_total AS (
    -- Total COGS per product-store for full year 2016
    SELECT
        fs.product_key,
        fs.store_key,
        SUM(fs.cogs)           AS total_cogs,
        SUM(fs.sales_quantity) AS total_qty_sold,
        SUM(fs.sales_dollars)  AS total_revenue
    FROM warehouse.fact_sales fs
    JOIN warehouse.dim_date dd ON dd.date_key = fs.date_key
    WHERE dd.year = 2016
    GROUP BY fs.product_key, fs.store_key
),
avg_inventory AS (
    -- Average inventory cost: (BEG + END) / 2
    SELECT
        fis.product_key,
        fis.store_key,
        MAX(CASE WHEN fis.snapshot_type = 'BEG' THEN fis.on_hand_cost ELSE 0 END) AS beg_inv_cost,
        MAX(CASE WHEN fis.snapshot_type = 'END' THEN fis.on_hand_cost ELSE 0 END) AS end_inv_cost,
        MAX(CASE WHEN fis.snapshot_type = 'BEG' THEN fis.on_hand_qty  ELSE 0 END) AS beg_inv_qty,
        MAX(CASE WHEN fis.snapshot_type = 'END' THEN fis.on_hand_qty  ELSE 0 END) AS end_inv_qty
    FROM warehouse.fact_inventory_snapshot fis
    GROUP BY fis.product_key, fis.store_key
)
SELECT
    dp.brand_id,
    dp.description,
    dp.classification_name,
    dp.size,
    ds.store_id,
    ds.city,
    ct.total_cogs,
    ct.total_qty_sold,
    ct.total_revenue,
    ai.beg_inv_cost,
    ai.end_inv_cost,
    ROUND((ai.beg_inv_cost + ai.end_inv_cost) / 2.0, 2)                            AS avg_inv_cost,
    -- Inventory Turnover
    CASE
        WHEN (ai.beg_inv_cost + ai.end_inv_cost) > 0
        THEN ROUND(ct.total_cogs / ((ai.beg_inv_cost + ai.end_inv_cost) / 2.0), 4)
        ELSE NULL
    END                                                                             AS inventory_turnover,
    -- DSI
    CASE
        WHEN (ai.beg_inv_cost + ai.end_inv_cost) > 0 AND ct.total_cogs > 0
        THEN ROUND(365.0 / (ct.total_cogs / ((ai.beg_inv_cost + ai.end_inv_cost) / 2.0)), 1)
        ELSE NULL
    END                                                                             AS dsi_days
FROM cogs_total ct
JOIN avg_inventory              ai ON ai.product_key = ct.product_key AND ai.store_key = ct.store_key
JOIN warehouse.dim_product      dp ON dp.product_key = ct.product_key
JOIN warehouse.dim_store        ds ON ds.store_key   = ct.store_key
ORDER BY inventory_turnover DESC NULLS LAST;

-- Aggregated by classification (for Power BI bar chart)
CREATE OR REPLACE VIEW warehouse.vw_kpi_turnover_by_category AS
SELECT
    dp.classification_name,
    ROUND(SUM(fs.cogs), 2)                                         AS total_cogs,
    ROUND(AVG(
        CASE WHEN (beg.on_hand_cost + ed.on_hand_cost) > 0
             THEN fs_agg.cogs_sum / ((beg.on_hand_cost + ed.on_hand_cost) / 2.0)
        END
    ), 4)                                                          AS avg_turnover,
    ROUND(365.0 / NULLIF(AVG(
        CASE WHEN (beg.on_hand_cost + ed.on_hand_cost) > 0
             THEN fs_agg.cogs_sum / ((beg.on_hand_cost + ed.on_hand_cost) / 2.0)
        END
    ), 0), 1)                                                      AS avg_dsi
FROM warehouse.vw_kpi_inventory_turnover v
JOIN warehouse.dim_product dp ON dp.description = v.description
JOIN warehouse.fact_sales  fs ON fs.product_key = dp.product_key
GROUP BY dp.classification_name;
