-- =============================================================
-- 02_stockout_rate.sql
-- KPI: Stockout Rate
--
-- Definition: % of SKU-Store combinations where ending on_hand = 0
-- Also flags SKUs that had sales but ended with 0 stock (true stockout)
-- =============================================================

CREATE OR REPLACE VIEW warehouse.vw_kpi_stockout AS
WITH end_inv AS (
    SELECT
        fis.product_key,
        fis.store_key,
        fis.on_hand_qty AS end_on_hand
    FROM warehouse.fact_inventory_snapshot fis
    WHERE fis.snapshot_type = 'END'
),
sales_2016 AS (
    SELECT
        fs.product_key,
        fs.store_key,
        SUM(fs.sales_quantity) AS total_qty_sold
    FROM warehouse.fact_sales fs
    JOIN warehouse.dim_date dd ON dd.date_key = fs.date_key
    WHERE dd.year = 2016
    GROUP BY fs.product_key, fs.store_key
),
base AS (
    SELECT
        ei.product_key,
        ei.store_key,
        ei.end_on_hand,
        COALESCE(s.total_qty_sold, 0) AS total_qty_sold,
        CASE WHEN ei.end_on_hand = 0                             THEN TRUE ELSE FALSE END AS is_stockout,
        CASE WHEN ei.end_on_hand = 0 AND COALESCE(s.total_qty_sold, 0) > 0 THEN TRUE ELSE FALSE END AS is_true_stockout
    FROM end_inv ei
    LEFT JOIN sales_2016 s ON s.product_key = ei.product_key AND s.store_key = ei.store_key
)
SELECT
    dp.brand_id,
    dp.description,
    dp.classification_name,
    ds.store_id,
    ds.city,
    b.end_on_hand,
    b.total_qty_sold,
    b.is_stockout,
    b.is_true_stockout,
    -- Risk score: sold items with 0 end stock = highest risk
    CASE
        WHEN b.is_true_stockout THEN 'HIGH'
        WHEN b.is_stockout      THEN 'MEDIUM'
        WHEN b.end_on_hand <= 3 THEN 'LOW'
        ELSE 'OK'
    END AS stockout_risk
FROM base b
JOIN warehouse.dim_product dp ON dp.product_key = b.product_key
JOIN warehouse.dim_store   ds ON ds.store_key   = b.store_key
ORDER BY b.is_true_stockout DESC, b.total_qty_sold DESC;

-- Stockout Rate summary per store
CREATE OR REPLACE VIEW warehouse.vw_kpi_stockout_rate_summary AS
SELECT
    ds.store_id,
    ds.city,
    COUNT(*)                                                           AS total_skus,
    SUM(CASE WHEN fis.on_hand_qty = 0 THEN 1 ELSE 0 END)              AS stockout_count,
    ROUND(
        100.0 * SUM(CASE WHEN fis.on_hand_qty = 0 THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0), 2
    )                                                                  AS stockout_rate_pct
FROM warehouse.fact_inventory_snapshot fis
JOIN warehouse.dim_store ds ON ds.store_key = fis.store_key
WHERE fis.snapshot_type = 'END'
GROUP BY ds.store_id, ds.city
ORDER BY stockout_rate_pct DESC;
