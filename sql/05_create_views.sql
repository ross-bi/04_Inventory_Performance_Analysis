-- =============================================================================
-- 04 Inventory Performance Analysis
-- Script 05: KPI Analytical Views (Semantic Layer for Power BI)
-- =============================================================================

SET search_path = inventory;


-- VIEW 1: Inventory Turnover + DSI
-- Grain: per product x per store
CREATE OR REPLACE VIEW vw_inventory_turnover AS
WITH
cogs AS (
    SELECT store_key, product_key,
           SUM(sales_dollars) AS total_cogs
    FROM fact_sales
    GROUP BY store_key, product_key
),
avg_inventory AS (
    SELECT store_key, product_key,
           SUM(CASE WHEN period_type = 'BEG' THEN inventory_value ELSE 0 END) AS beg_inventory_value,
           SUM(CASE WHEN period_type = 'END' THEN inventory_value ELSE 0 END) AS end_inventory_value,
           (SUM(CASE WHEN period_type = 'BEG' THEN inventory_value ELSE 0 END)
            + SUM(CASE WHEN period_type = 'END' THEN inventory_value ELSE 0 END)) / 2.0 AS avg_inventory_value
    FROM fact_inventory_snapshot
    GROUP BY store_key, product_key
)
SELECT
    p.brand, p.description, p.size, p.classification,
    s.store_id, s.city,
    COALESCE(c.total_cogs, 0)                       AS total_cogs,
    ai.beg_inventory_value,
    ai.end_inventory_value,
    ai.avg_inventory_value,
    CASE
        WHEN ai.avg_inventory_value > 0
        THEN ROUND(c.total_cogs / ai.avg_inventory_value, 2)
        ELSE NULL
    END                                             AS inventory_turnover,
    CASE
        WHEN ai.avg_inventory_value > 0 AND c.total_cogs > 0
        THEN ROUND(365.0 / (c.total_cogs / ai.avg_inventory_value), 1)
        ELSE NULL
    END                                             AS dsi
FROM avg_inventory ai
JOIN cogs         c  ON c.store_key   = ai.store_key
                     AND c.product_key = ai.product_key
JOIN dim_product  p  ON p.product_key = ai.product_key
JOIN dim_store    s  ON s.store_key   = ai.store_key;


-- VIEW 2: Stockout Rate
-- Grain: per store
CREATE OR REPLACE VIEW vw_stockout_rate AS
SELECT
    s.store_id, s.city,
    COUNT(DISTINCT fis.product_key)                                        AS total_skus,
    COUNT(DISTINCT CASE WHEN fis.on_hand_qty = 0 THEN fis.product_key END) AS stockout_skus,
    ROUND(
        COUNT(DISTINCT CASE WHEN fis.on_hand_qty = 0 THEN fis.product_key END)
        * 100.0 / NULLIF(COUNT(DISTINCT fis.product_key), 0)
    , 2)                                                                   AS stockout_rate_pct
FROM fact_inventory_snapshot fis
JOIN dim_store s ON s.store_key = fis.store_key
WHERE fis.period_type = 'END'
GROUP BY s.store_id, s.city;


-- VIEW 3: Overstock & Reorder Point
-- Grain: per product x per store
CREATE OR REPLACE VIEW vw_overstock AS
WITH daily_sales AS (
    SELECT store_key, product_key,
           COUNT(DISTINCT date_key)  AS selling_days,
           SUM(sales_qty)            AS total_sales_qty
    FROM fact_sales
    GROUP BY store_key, product_key
),
lead_time_avg AS (
    SELECT product_key, vendor_key,
           ROUND(AVG(lead_time_days), 1) AS avg_lead_time_days
    FROM fact_purchases
    WHERE lead_time_days IS NOT NULL AND lead_time_days BETWEEN 1 AND 90
    GROUP BY product_key, vendor_key
),
reorder_calc AS (
    SELECT
        ds.store_key, ds.product_key,
        ds.total_sales_qty / NULLIF(ds.selling_days, 0)       AS avg_daily_sales,
        COALESCE(lt.avg_lead_time_days, 7)                    AS lead_time_days,
        -- Safety stock = 1.5 x avg_daily_sales x SQRT(lead_time)  [industry heuristic]
        ROUND(1.5 * (ds.total_sales_qty / NULLIF(ds.selling_days, 0))
              * SQRT(COALESCE(lt.avg_lead_time_days, 7)), 2)  AS safety_stock
    FROM daily_sales ds
    LEFT JOIN lead_time_avg lt USING (product_key)
),
reorder_point AS (
    SELECT store_key, product_key,
           avg_daily_sales, lead_time_days, safety_stock,
           ROUND(avg_daily_sales * lead_time_days + safety_stock, 2) AS reorder_point_qty
    FROM reorder_calc
)
SELECT
    p.brand, p.description, p.size, p.classification,
    s.store_id, s.city,
    fis.on_hand_qty                 AS ending_qty,
    rp.reorder_point_qty,
    rp.avg_daily_sales,
    rp.lead_time_days,
    rp.safety_stock,
    CASE WHEN fis.on_hand_qty > rp.reorder_point_qty * 1.5 THEN TRUE ELSE FALSE END AS is_overstock,
    CASE
        WHEN fis.on_hand_qty = 0                            THEN 'STOCKOUT'
        WHEN fis.on_hand_qty <= rp.reorder_point_qty        THEN 'REORDER NOW'
        WHEN fis.on_hand_qty <= rp.reorder_point_qty * 1.5 THEN 'ADEQUATE'
        ELSE 'OVERSTOCK'
    END                             AS stock_status
FROM fact_inventory_snapshot fis
JOIN dim_product  p  ON p.product_key  = fis.product_key
JOIN dim_store    s  ON s.store_key    = fis.store_key
LEFT JOIN reorder_point rp
       ON rp.store_key = fis.store_key AND rp.product_key = fis.product_key
WHERE fis.period_type = 'END';


-- VIEW 4: Reorder Recommendations (actionable output)
CREATE OR REPLACE VIEW vw_reorder_recommendations AS
SELECT
    brand, description, size, classification,
    store_id, city,
    ending_qty, reorder_point_qty, avg_daily_sales,
    lead_time_days, safety_stock, stock_status,
    GREATEST(0, ROUND(reorder_point_qty * 2.0 - ending_qty, 0)) AS suggested_order_qty
FROM vw_overstock
WHERE stock_status IN ('STOCKOUT', 'REORDER NOW')
ORDER BY
    CASE stock_status WHEN 'STOCKOUT' THEN 1 WHEN 'REORDER NOW' THEN 2 ELSE 3 END,
    avg_daily_sales DESC;


-- VIEW 5: KPI Summary Dashboard (one row per store)
CREATE OR REPLACE VIEW vw_kpi_summary AS
WITH
turnover_agg AS (
    SELECT store_id, city,
           ROUND(AVG(inventory_turnover), 2) AS avg_inventory_turnover,
           ROUND(AVG(dsi), 1)               AS avg_dsi
    FROM vw_inventory_turnover
    WHERE inventory_turnover IS NOT NULL
    GROUP BY store_id, city
),
stockout_agg AS (
    SELECT store_id, stockout_rate_pct FROM vw_stockout_rate
),
overstock_agg AS (
    SELECT store_id,
           COUNT(*)                                                AS total_skus,
           COUNT(CASE WHEN is_overstock THEN 1 END)               AS overstock_skus,
           ROUND(COUNT(CASE WHEN is_overstock THEN 1 END) * 100.0
                 / NULLIF(COUNT(*), 0), 2)                        AS overstock_pct
    FROM vw_overstock
    GROUP BY store_id
)
SELECT
    t.store_id, t.city,
    t.avg_inventory_turnover,
    t.avg_dsi,
    s.stockout_rate_pct,
    o.overstock_pct,
    o.total_skus,
    o.overstock_skus
FROM turnover_agg  t
JOIN stockout_agg  s USING (store_id)
JOIN overstock_agg o USING (store_id)
ORDER BY t.avg_inventory_turnover DESC;
