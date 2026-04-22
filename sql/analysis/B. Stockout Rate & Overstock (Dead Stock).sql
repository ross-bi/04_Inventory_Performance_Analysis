-- B1: Stockout Rate
-- Stockout = products with ending on_hand = 0
WITH end_inv AS (
    SELECT
        product_sk,
        store_sk,
        SUM(quantity_on_hand) AS end_qty
    FROM marts.fact_inventory_snapshot
    WHERE snapshot_type = 'ENDING'
    GROUP BY product_sk, store_sk
)
SELECT
    COUNT(*)                                                        AS total_sku_store_combos,
    COUNT(*) FILTER (WHERE end_qty = 0)                            AS stockout_count,
    ROUND(100.0 * COUNT(*) FILTER (WHERE end_qty = 0)
          / NULLIF(COUNT(*), 0), 2)                                AS stockout_rate_pct
FROM end_inv;

-- B2: Dead Stock (overstock) — end_inv > 0 but NO sales in 2016
WITH end_inv AS (
    SELECT product_sk, store_sk, SUM(quantity_on_hand) AS end_qty
    FROM marts.fact_inventory_snapshot
    WHERE snapshot_type = 'ENDING'
    GROUP BY product_sk, store_sk
),
sold AS (
    SELECT DISTINCT product_sk, store_sk
    FROM marts.fact_sales
)
SELECT
    COUNT(*)                                               AS total_ending_positions,
    COUNT(*) FILTER (WHERE s.product_sk IS NULL AND e.end_qty > 0) AS dead_stock_count,
    ROUND(100.0 * COUNT(*) FILTER (WHERE s.product_sk IS NULL AND e.end_qty > 0)
          / NULLIF(COUNT(*), 0), 2)                        AS dead_stock_pct,
    ROUND(SUM(CASE WHEN s.product_sk IS NULL AND e.end_qty > 0
              THEN e.end_qty ELSE 0 END), 0)               AS dead_stock_total_units
FROM end_inv e
LEFT JOIN sold s ON e.product_sk = s.product_sk AND e.store_sk = s.store_sk;