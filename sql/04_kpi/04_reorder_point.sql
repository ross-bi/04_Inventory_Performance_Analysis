-- =============================================================
-- 04_reorder_point.sql
-- KPI: Reorder Point (ROP) & Replenishment Recommendation
--
-- Formula:
--   ROP = Avg Daily Sales Qty × Avg Lead Time (days)
--   Safety Stock = Z × σ(daily_sales) × √(lead_time)   [Z=1.65 for 95% service level]
--   ROP with Safety Stock = ROP + Safety Stock
--
-- Recommendation logic:
--   If end_on_hand <= ROP_with_safety → REORDER NOW
--   If end_on_hand <= 2×ROP           → MONITOR
--   Else                              → ADEQUATE
-- =============================================================

CREATE OR REPLACE VIEW warehouse.vw_kpi_reorder_point AS
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
sales_stats AS (
    SELECT
        product_key,
        store_key,
        ROUND(SUM(qty_sold)::NUMERIC / 365, 4)             AS avg_daily_sales,
        ROUND(STDDEV_POP(qty_sold)::NUMERIC, 4)            AS stddev_daily_sales
    FROM daily_sales
    GROUP BY product_key, store_key
),
avg_lead AS (
    SELECT
        product_key,
        store_key,
        ROUND(AVG(lead_time_days), 1)                       AS avg_lead_days,
        ROUND(STDDEV_POP(lead_time_days)::NUMERIC, 1)       AS stddev_lead_days
    FROM warehouse.fact_purchases
    WHERE lead_time_days BETWEEN 0 AND 180
    GROUP BY product_key, store_key
),
end_inv AS (
    SELECT product_key, store_key, on_hand_qty
    FROM warehouse.fact_inventory_snapshot
    WHERE snapshot_type = 'END'
)
SELECT
    dp.brand_id,
    dp.description,
    dp.classification_name,
    dp.size,
    ds.store_id,
    ds.city,
    ss.avg_daily_sales,
    ss.stddev_daily_sales,
    COALESCE(al.avg_lead_days, 7)                            AS avg_lead_days,
    -- Basic ROP
    ROUND(ss.avg_daily_sales * COALESCE(al.avg_lead_days, 7), 2) AS rop_basic,
    -- Safety stock at 95% service level (Z = 1.65)
    ROUND(
        1.65 * SQRT(
            COALESCE(al.avg_lead_days, 7)
            * POWER(COALESCE(ss.stddev_daily_sales, 0), 2)
        ), 2
    )                                                        AS safety_stock,
    -- ROP with safety stock
    ROUND(
        ss.avg_daily_sales * COALESCE(al.avg_lead_days, 7)
        + 1.65 * SQRT(
            COALESCE(al.avg_lead_days, 7)
            * POWER(COALESCE(ss.stddev_daily_sales, 0), 2)
        ), 2
    )                                                        AS rop_with_safety,
    ei.on_hand_qty                                           AS current_on_hand,
    -- Replenishment recommendation
    CASE
        WHEN ei.on_hand_qty <= ROUND(
            ss.avg_daily_sales * COALESCE(al.avg_lead_days, 7)
            + 1.65 * SQRT(
                COALESCE(al.avg_lead_days, 7)
                * POWER(COALESCE(ss.stddev_daily_sales, 0), 2)
            ), 0)
        THEN 'REORDER NOW'
        WHEN ei.on_hand_qty <= ROUND(
            2 * ss.avg_daily_sales * COALESCE(al.avg_lead_days, 7), 0)
        THEN 'MONITOR'
        ELSE 'ADEQUATE'
    END                                                      AS replenishment_status,
    -- Suggested order quantity (one lead-time cycle worth)
    GREATEST(
        ROUND(
            ss.avg_daily_sales * COALESCE(al.avg_lead_days, 7)
            + 1.65 * SQRT(
                COALESCE(al.avg_lead_days, 7)
                * POWER(COALESCE(ss.stddev_daily_sales, 0), 2)
            ) - ei.on_hand_qty, 0
        ), 0
    )                                                        AS suggested_order_qty
FROM sales_stats ss
JOIN end_inv               ei ON ei.product_key = ss.product_key AND ei.store_key = ss.store_key
JOIN warehouse.dim_product dp ON dp.product_key = ss.product_key
JOIN warehouse.dim_store   ds ON ds.store_key   = ss.store_key
LEFT JOIN avg_lead         al ON al.product_key = ss.product_key AND al.store_key = ss.store_key
ORDER BY replenishment_status, suggested_order_qty DESC;
