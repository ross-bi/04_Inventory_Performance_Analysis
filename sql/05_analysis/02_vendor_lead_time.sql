-- =============================================================
-- 02_vendor_lead_time.sql
-- Analysis: Vendor Lead Time Performance
--
-- Analyses lead time consistency and reliability per vendor
-- to support reorder point calibration
-- =============================================================

CREATE OR REPLACE VIEW warehouse.vw_analysis_vendor_lead_time AS
SELECT
    dv.vendor_number,
    dv.vendor_name,
    COUNT(fp.purchase_key)                               AS total_pos,
    ROUND(AVG(fp.lead_time_days), 1)                    AS avg_lead_days,
    MIN(fp.lead_time_days)                              AS min_lead_days,
    MAX(fp.lead_time_days)                              AS max_lead_days,
    ROUND(STDDEV_POP(fp.lead_time_days)::NUMERIC, 2)    AS stddev_lead_days,
    -- Lead time reliability: CV = stddev / mean (lower = more reliable)
    ROUND(
        STDDEV_POP(fp.lead_time_days) / NULLIF(AVG(fp.lead_time_days), 0),
        4
    )                                                   AS cv_lead_time,
    SUM(fp.dollars)                                     AS total_purchase_value,
    -- Lead time performance bucket
    CASE
        WHEN ROUND(AVG(fp.lead_time_days), 0) <= 5     THEN 'FAST (≤5d)'
        WHEN ROUND(AVG(fp.lead_time_days), 0) <= 14    THEN 'STANDARD (6-14d)'
        WHEN ROUND(AVG(fp.lead_time_days), 0) <= 30    THEN 'SLOW (15-30d)'
        ELSE 'VERY SLOW (>30d)'
    END                                                 AS lead_time_band
FROM warehouse.fact_purchases fp
JOIN warehouse.dim_vendor dv ON dv.vendor_key = fp.vendor_key
WHERE fp.lead_time_days IS NOT NULL AND fp.lead_time_days BETWEEN 0 AND 180
GROUP BY dv.vendor_number, dv.vendor_name
ORDER BY avg_lead_days ASC;
