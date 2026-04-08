-- =============================================
-- Module 5a: 庫存數量異常（合併一行輸出）
-- =============================================
SELECT
    'beg_inv'                                              AS table_name,
    COUNT(*) FILTER (WHERE on_hand < 0)                    AS negative_on_hand,
    COUNT(*) FILTER (WHERE on_hand = 0)                    AS zero_on_hand,
    MIN(on_hand)                                           AS min_on_hand,
    MAX(on_hand)                                           AS max_on_hand,
    ROUND(AVG(on_hand), 2)                                 AS avg_on_hand
FROM stg.beg_inv
UNION ALL
SELECT
    'end_inv',
    COUNT(*) FILTER (WHERE on_hand < 0),
    COUNT(*) FILTER (WHERE on_hand = 0),
    MIN(on_hand),
    MAX(on_hand),
    ROUND(AVG(on_hand), 2)
FROM stg.end_inv;

-- =============================================
-- Module 5b: 銷售金額異常分佈
-- =============================================
SELECT
    MIN(sales_dollars)                                          AS min_sales,
    MAX(sales_dollars)                                          AS max_sales,
    ROUND(AVG(sales_dollars), 2)                                AS avg_sales,
    PERCENTILE_CONT(0.50) WITHIN GROUP
        (ORDER BY sales_dollars)                                AS median_sales,
    PERCENTILE_CONT(0.95) WITHIN GROUP
        (ORDER BY sales_dollars)                                AS p95_sales,
    PERCENTILE_CONT(0.99) WITHIN GROUP
        (ORDER BY sales_dollars)                                AS p99_sales,
    COUNT(*) FILTER (WHERE sales_dollars <= 0)                  AS neg_or_zero_sales,
    COUNT(*) FILTER (WHERE sales_quantity <= 0)                 AS neg_or_zero_qty,
    -- 單價一致性：sales_price ≈ sales_dollars / sales_quantity
    COUNT(*) FILTER (
        WHERE ABS(sales_price - sales_dollars
              / NULLIF(sales_quantity, 0)) > 0.05
    )                                                           AS price_calc_mismatch
FROM stg.sales;

-- =============================================
-- Module 5c: 採購單價核對 & 日期邏輯錯誤
-- =============================================
SELECT
    COUNT(*)                                                    AS total_rows,
    -- 單價核對：purchase_price ≈ dollars / quantity
    COUNT(*) FILTER (
        WHERE ABS(purchase_price
              - (dollars / NULLIF(quantity, 0))) > 0.02
    )                                                           AS price_mismatch,
    -- 負數或零採購量
    COUNT(*) FILTER (WHERE quantity   <= 0)                     AS neg_zero_qty,
    COUNT(*) FILTER (WHERE dollars    <= 0)                     AS neg_zero_dollars,
    -- 日期邏輯錯誤
    COUNT(*) FILTER (WHERE receiving_date < po_date)            AS recv_before_po,
    COUNT(*) FILTER (WHERE invoice_date   < po_date)            AS inv_before_po,
    COUNT(*) FILTER (WHERE pay_date       < invoice_date)       AS pay_before_inv,
    -- 極端前置時間（>90天 或 <0天）
    COUNT(*) FILTER (
        WHERE (receiving_date - po_date) > 90
    )                                                           AS lead_time_over_90d,
    COUNT(*) FILTER (
        WHERE (receiving_date - po_date) < 0
    )                                                           AS lead_time_negative
FROM stg.purchases;

-- =============================================
-- Module 5d: 重複鍵偵測（同一 inventory_id 在 beg_inv 出現超過 1 次）
-- =============================================
SELECT
    'beg_inv'                                                   AS table_name,
    COUNT(*)                                                    AS dup_inventory_id_count
FROM (
    SELECT inventory_id
    FROM stg.beg_inv
    GROUP BY inventory_id
    HAVING COUNT(*) > 1
) t
UNION ALL
SELECT
    'end_inv',
    COUNT(*)
FROM (
    SELECT inventory_id
    FROM stg.end_inv
    GROUP BY inventory_id
    HAVING COUNT(*) > 1
) t
UNION ALL
SELECT
    'purchase_prices',
    COUNT(*)
FROM (
    SELECT brand, size
    FROM stg.purchase_prices
    GROUP BY brand, size
    HAVING COUNT(*) > 1
) t;