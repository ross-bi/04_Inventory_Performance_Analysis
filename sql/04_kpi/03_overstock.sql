-- =============================================================
-- 03_overstock.sql
-- KPI: Overstock %
--
-- Definition: SKUs where ending on_hand > 2× Reorder Point
-- Also computes: excess units, excess cost tied up in overstock
-- =============================================================

-- First create reorder point CTE (shared with reorder_point.sql view)
CREATE OR REPLACE VIEW warehouse.vw_kpi_overstock AS
WITH daily_sales AS (
    SELECT
        fs.product_key,
        fs.store_key,
        dd.full_date,
        SUM(fs.sales_quantity) AS qty_sold
    FROM warehouse.fact_sales fs
    JOIN warehouse.dim_date dd ON dd.date_key = fs.date_key
    WHERE dd.year = 2016
    GROUP BY fs.product_key, fs.store_key, dd.full_date
),
avg_daily_sales AS (
    SELECT
        product_key,
        store_key,
        -- Average over 365 days (include zero-sale days)
        ROUND(SUM(qty_sold)::NUMERIC / 365, 4) AS avg_daily_sales
    FROM daily_sales
    GROUP BY product_key, store_key
),
avg_lead_time AS (
    SELECT
        product_key,
        store_key,
        ROUND(AVG(lead_time_days), 1) AS avg_lead_days
    FROM warehouse.fact_purchases
    WHERE lead_time_days IS NOT NULL AND lead_time_days BETWEEN 0 AND 180
    GROUP BY product_key, store_key
),
reorder_points AS (
    SELECT
        ads.product_key,
        ads.store_key,
        ads.avg_daily_sales,
        COALESCE(alt.avg_lead_days, 7) AS avg_lead_days,   -- default 7 days if no PO history
        ROUND(ads.avg_daily_sales * COALESCE(alt.avg_lead_days, 7), 2) AS reorder_point
    FROM avg_daily_sales ads
    LEFT JOIN avg_lead_time alt
           ON alt.product_key = ads.product_key
          AND alt.store_key   = ads.store_key
),
end_inv AS (
    SELECT product_key, store_key, on_hand_qty, on_hand_cost
    FROM warehouse.fact_inventory_snapshot
    WHERE snapshot_type = 'END'
)
SELECT
    dp.brand_id,
    dp.description,
    dp.classification_name,
    ds.store_id,
    ds.city,
    ei.on_hand_qty                              AS end_on_hand,
    rp.reorder_point,
    rp.avg_daily_sales,
    rp.avg_lead_days,
    -- Overstock flag: on hand > 2× ROP
    CASE WHEN ei.on_hand_qty > 2 * rp.reorder_point THEN TRUE ELSE FALSE END  AS is_overstock,
    -- Excess units
    GREATEST(ei.on_hand_qty - ROUND(2 * rp.reorder_point), 0)                 AS excess_units,
    -- Excess cost tied up
    ROUND(
        GREATEST(ei.on_hand_qty - ROUND(2 * rp.reorder_point), 0)
        * COALESCE(dp.purchase_price, 0), 2
    )                                                                          AS excess_cost
FROM end_inv ei
JOIN reorder_points       rp ON rp.product_key = ei.product_key AND rp.store_key = ei.store_key
JOIN warehouse.dim_product dp ON dp.product_key = ei.product_key
JOIN warehouse.dim_store   ds ON ds.store_key   = ei.store_key
ORDER BY excess_cost DESC NULLS LAST;

-- Overstock summary per store
CREATE OR REPLACE VIEW warehouse.vw_kpi_overstock_summary AS
SELECT
    store_id,
    city,
    COUNT(*)                                                      AS total_skus,
    SUM(CASE WHEN is_overstock THEN 1 ELSE 0 END)                 AS overstock_count,
    ROUND(
        100.0 * SUM(CASE WHEN is_overstock THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0), 2
    )                                                             AS overstock_pct,
    SUM(excess_cost)                                              AS total_excess_cost
FROM warehouse.vw_kpi_overstock
GROUP BY store_id, city
ORDER BY total_excess_cost DESC;
