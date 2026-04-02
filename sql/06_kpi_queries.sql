-- =============================================================================
-- 04 Inventory Performance Analysis
-- Script 06: Standalone KPI Validation Queries
-- =============================================================================

SET search_path = inventory;


-- Q1: Overall Portfolio KPI Summary
SELECT
    ROUND(AVG(avg_inventory_turnover), 2) AS portfolio_avg_turnover,
    ROUND(AVG(avg_dsi), 1)               AS portfolio_avg_dsi,
    ROUND(AVG(stockout_rate_pct), 2)     AS portfolio_stockout_rate_pct,
    ROUND(AVG(overstock_pct), 2)         AS portfolio_overstock_pct
FROM vw_kpi_summary;


-- Q2: Top 10 worst-performing stores by Inventory Turnover
SELECT store_id, city,
       avg_inventory_turnover, avg_dsi,
       stockout_rate_pct, overstock_pct
FROM vw_kpi_summary
ORDER BY avg_inventory_turnover ASC
LIMIT 10;


-- Q3: Top 10 slow-moving SKUs (dead stock candidates)
SELECT
    brand, description, size, classification,
    ROUND(AVG(dsi), 1)               AS avg_dsi,
    ROUND(AVG(inventory_turnover), 2) AS avg_turnover,
    COUNT(DISTINCT store_id)          AS stores_carrying
FROM vw_inventory_turnover
WHERE dsi IS NOT NULL
GROUP BY brand, description, size, classification
ORDER BY avg_dsi DESC
LIMIT 10;


-- Q4: Stockout Rate by product classification (WINE vs SPIRITS)
SELECT
    p.classification,
    COUNT(DISTINCT fis.product_key)                                        AS total_skus,
    COUNT(DISTINCT CASE WHEN fis.on_hand_qty = 0 THEN fis.product_key END) AS stockout_skus,
    ROUND(
        COUNT(DISTINCT CASE WHEN fis.on_hand_qty = 0 THEN fis.product_key END)
        * 100.0 / NULLIF(COUNT(DISTINCT fis.product_key), 0)
    , 2)                                                                   AS stockout_rate_pct
FROM fact_inventory_snapshot fis
JOIN dim_product p ON p.product_key = fis.product_key
WHERE fis.period_type = 'END'
GROUP BY p.classification
ORDER BY stockout_rate_pct DESC;


-- Q5: Urgent Reorder Recommendations (top 20)
SELECT
    brand, description, size,
    store_id, city, stock_status,
    ending_qty, reorder_point_qty, suggested_order_qty,
    avg_daily_sales, lead_time_days
FROM vw_reorder_recommendations
LIMIT 20;


-- Q6: Lead Time Analysis by Vendor
SELECT
    v.vendor_name,
    COUNT(*)                             AS total_orders,
    ROUND(AVG(fp.lead_time_days), 1)     AS avg_lead_time_days,
    MIN(fp.lead_time_days)               AS min_lead_time,
    MAX(fp.lead_time_days)               AS max_lead_time,
    ROUND(STDDEV(fp.lead_time_days), 1)  AS stddev_lead_time
FROM fact_purchases fp
JOIN dim_vendor v ON v.vendor_key = fp.vendor_key
WHERE fp.lead_time_days IS NOT NULL
  AND fp.lead_time_days BETWEEN 1 AND 90
GROUP BY v.vendor_name
HAVING COUNT(*) >= 10
ORDER BY avg_lead_time_days DESC;


-- Q7: Monthly Sales vs Inventory Value Trend
SELECT
    dd.year, dd.month, dd.month_name,
    fis.period_type,
    ROUND(SUM(fis.inventory_value), 2) AS total_inventory_value,
    COUNT(DISTINCT fis.product_key)    AS unique_skus
FROM fact_inventory_snapshot fis
JOIN dim_date dd ON dd.date_key = fis.date_key
GROUP BY dd.year, dd.month, dd.month_name, fis.period_type
ORDER BY dd.year, dd.month, fis.period_type;


-- Q8: Overstock Capital Tied Up by Classification
SELECT
    o.classification,
    COUNT(CASE WHEN o.is_overstock THEN 1 END)  AS overstock_sku_count,
    ROUND(SUM(
        CASE WHEN o.is_overstock
        THEN fis.on_hand_qty * fis.unit_price ELSE 0 END
    ), 2)                                       AS overstock_inventory_value
FROM vw_overstock o
JOIN fact_inventory_snapshot fis
    ON fis.product_key = (SELECT product_key FROM dim_product
                          WHERE brand = o.brand
                            AND description = o.description
                            AND size = o.size LIMIT 1)
    AND fis.period_type = 'END'
JOIN dim_product p ON p.product_key = fis.product_key
GROUP BY o.classification
ORDER BY overstock_inventory_value DESC;
