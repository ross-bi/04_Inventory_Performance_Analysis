-- A1: Row counts
SELECT 'fact_sales' AS table_name, COUNT(*) AS row_count FROM marts.fact_sales
UNION ALL
SELECT 'fact_inventory_snapshot', COUNT(*) FROM marts.fact_inventory_snapshot
UNION ALL
SELECT 'dim_product', COUNT(*) FROM marts.dim_product
UNION ALL
SELECT 'dim_store', COUNT(*) FROM marts.dim_store
UNION ALL
SELECT 'dim_vendor', COUNT(*) FROM marts.dim_vendor;

-- A2: Total Sales Revenue & Quantity
SELECT
    ROUND(SUM(sales_dollars),0)   AS total_sales_revenue,
    SUM(sales_quantity)           AS total_sales_qty,
    MIN(sales_date)               AS date_start,
    MAX(sales_date)               AS date_end
FROM marts.fact_sales;

-- A3: Inventory Turnover & DSI (全年)
-- Turnover = COGS / Avg Inventory Value
-- DSI      = 365 / Turnover
WITH
beg AS (
    SELECT SUM(total_inventory_value) AS beg_value
    FROM marts.fact_inventory_snapshot
    WHERE snapshot_type = 'BEGINNING'
),
end_ AS (
    SELECT SUM(total_inventory_value) AS end_value
    FROM marts.fact_inventory_snapshot
    WHERE snapshot_type = 'ENDING'
),
cogs AS (
    SELECT SUM(estimated_cogs) AS total_cogs
    FROM marts.fact_sales
)
SELECT
    ROUND(cogs.total_cogs, 0)                                                     AS total_cogs,
    ROUND(beg.beg_value, 0)                                                       AS beg_inventory_value,
    ROUND(end_.end_value, 0)                                                       AS end_inventory_value,
    ROUND((beg.beg_value + end_.end_value) / 2, 0)                                AS avg_inventory_value,
    ROUND(cogs.total_cogs / NULLIF((beg.beg_value + end_.end_value) / 2, 0), 2)  AS inventory_turnover,
    ROUND(365 / NULLIF(cogs.total_cogs / NULLIF((beg.beg_value + end_.end_value) / 2, 0), 0), 1) AS dsi_days
FROM cogs, beg, end_;