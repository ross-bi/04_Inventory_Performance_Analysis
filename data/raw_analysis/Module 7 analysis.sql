-- =============================================
-- Module 7a: 月銷售趨勢
-- =============================================
SELECT
    DATE_TRUNC('month', sales_date)                         AS sales_month,
    SUM(sales_quantity)                                     AS total_qty_sold,
    ROUND(SUM(sales_dollars)::numeric, 2)                   AS total_revenue,
    ROUND(AVG(sales_price)::numeric, 2)                     AS avg_selling_price,
    COUNT(DISTINCT inventory_id)                            AS distinct_skus_sold,
    COUNT(DISTINCT store)                                   AS active_stores,
    COUNT(DISTINCT brand)                                   AS active_brands
FROM stg.sales
GROUP BY 1
ORDER BY 1;

-- =============================================
-- Module 7b: 月採購趨勢
-- =============================================
SELECT
    DATE_TRUNC('month', po_date)                            AS po_month,
    SUM(quantity)                                           AS total_purchased,
    ROUND(SUM(dollars)::numeric, 2)                         AS total_purchase_value,
    ROUND(AVG(purchase_price)::numeric, 2)                  AS avg_purchase_price,
    COUNT(DISTINCT vendor_number)                           AS distinct_vendors,
    COUNT(DISTINCT brand)                                   AS distinct_brands,
    ROUND(AVG(receiving_date - po_date)::numeric, 2)        AS avg_lead_days
FROM stg.purchases
GROUP BY 1
ORDER BY 1;

-- =============================================
-- Module 7c: 月度庫存消耗 vs 補貨對比
-- =============================================
WITH monthly_sales AS (
    SELECT
        DATE_TRUNC('month', sales_date) AS month,
        SUM(sales_quantity)             AS qty_sold
    FROM stg.sales
    GROUP BY 1
),
monthly_purchases AS (
    SELECT
        DATE_TRUNC('month', receiving_date) AS month,
        SUM(quantity)                       AS qty_received
    FROM stg.purchases
    GROUP BY 1
)
SELECT
    COALESCE(s.month, p.month)              AS month,
    COALESCE(s.qty_sold, 0)                 AS qty_sold,
    COALESCE(p.qty_received, 0)             AS qty_received,
    COALESCE(p.qty_received, 0)
        - COALESCE(s.qty_sold, 0)           AS net_inv_change,
    CASE
        WHEN COALESCE(p.qty_received, 0) > COALESCE(s.qty_sold, 0)
            THEN 'OVERSTOCK_RISK'
        WHEN COALESCE(p.qty_received, 0) < COALESCE(s.qty_sold, 0)
            THEN 'STOCKOUT_RISK'
        ELSE 'BALANCED'
    END                                     AS inv_status
FROM monthly_sales s
FULL OUTER JOIN monthly_purchases p USING (month)
ORDER BY month;

-- =============================================
-- Module 7d: 缺貨訊號（期初有 → 期末消失 / 歸零）
-- =============================================
SELECT
    COUNT(DISTINCT b.inventory_id)
        FILTER (WHERE e.inventory_id IS NULL)               AS disappeared_items,
    COUNT(DISTINCT b.inventory_id)
        FILTER (WHERE e.on_hand = 0)                        AS zero_end_stock,
    COUNT(DISTINCT b.inventory_id)
        FILTER (WHERE e.on_hand > 0 AND b.on_hand > 0)     AS stable_items,
    COUNT(DISTINCT e.inventory_id)
        FILTER (WHERE b.inventory_id IS NULL)               AS new_items,
    -- 呆滯庫存初步偵測：期末庫存 > 0 且全年無銷售紀錄
    COUNT(DISTINCT e.inventory_id)
        FILTER (WHERE b.inventory_id IS NOT NULL
                  AND e.on_hand > 0
                  AND e.inventory_id NOT IN (
                      SELECT DISTINCT inventory_id FROM stg.sales
                  ))                                        AS potential_dead_stock
FROM stg.beg_inv b
FULL OUTER JOIN stg.end_inv e USING (inventory_id);

-- =============================================
-- Module 7e: 品牌層級銷售趨勢（前 10 品牌，月別）
-- =============================================
WITH top_brands AS (
    SELECT brand
    FROM stg.sales
    GROUP BY brand
    ORDER BY SUM(sales_dollars) DESC
    LIMIT 10
)
SELECT
    DATE_TRUNC('month', s.sales_date)   AS sales_month,
    s.brand,
    pp.description,
    SUM(s.sales_quantity)               AS monthly_qty,
    ROUND(SUM(s.sales_dollars)::numeric, 2) AS monthly_revenue
FROM stg.sales s
JOIN top_brands t USING (brand)
LEFT JOIN stg.purchase_prices pp USING (brand)
GROUP BY 1, 2, 3
ORDER BY 1, monthly_revenue DESC;