-- =============================================================
-- 01_slow_moving_inventory.sql
-- Analysis: Slow-Moving / Dead Stock Detection
--
-- Slow-moving: DSI > 180 days
-- Dead stock:  had 0 sales in 2016 but has ending inventory
-- =============================================================

CREATE OR REPLACE VIEW warehouse.vw_analysis_slow_moving AS
SELECT
    v.brand_id,
    v.description,
    v.classification_name,
    v.size,
    v.store_id,
    v.city,
    v.total_qty_sold,
    v.total_cogs,
    v.avg_inv_cost,
    v.inventory_turnover,
    v.dsi_days,
    CASE
        WHEN v.total_qty_sold = 0 AND v.end_inv_cost > 0 THEN 'DEAD STOCK'
        WHEN v.dsi_days > 180                            THEN 'SLOW MOVING'
        WHEN v.dsi_days > 90                             THEN 'MODERATE'
        ELSE 'ACTIVE'
    END AS stock_health,
    v.end_inv_cost AS ending_inv_cost_at_risk
FROM warehouse.vw_kpi_inventory_turnover v
WHERE v.dsi_days > 90 OR v.total_qty_sold = 0
ORDER BY v.dsi_days DESC NULLS LAST;
