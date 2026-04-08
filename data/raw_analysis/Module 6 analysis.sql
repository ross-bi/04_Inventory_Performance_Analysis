-- =============================================
-- Module 6a: 全年 COGS 估算 + 毛利結構（按門市）
-- =============================================
SELECT
    s.store,
    SUM(s.sales_quantity * pp.purchase_price)               AS est_cogs,
    SUM(s.sales_dollars)                                    AS total_revenue,
    SUM(s.sales_dollars)
        - SUM(s.sales_quantity * pp.purchase_price)         AS est_gross_profit,
    ROUND(
        (SUM(s.sales_dollars)
            - SUM(s.sales_quantity * pp.purchase_price))
        / NULLIF(SUM(s.sales_dollars), 0) * 100, 2
    )                                                       AS gross_margin_pct
FROM stg.sales s
JOIN stg.purchase_prices pp USING (brand)
GROUP BY s.store
ORDER BY total_revenue DESC;

-- =============================================
-- Module 6b: 平均庫存（BegInv + EndInv / 2），全 InventoryId
-- =============================================
SELECT
    COALESCE(b.store, e.store)                              AS store,
    COALESCE(b.brand, e.brand)                              AS brand,
    COALESCE(b.inventory_id, e.inventory_id)                AS inventory_id,
    COALESCE(b.on_hand, 0)                                  AS beg_on_hand,
    COALESCE(e.on_hand, 0)                                  AS end_on_hand,
    ROUND(
        (COALESCE(b.on_hand, 0)
            + COALESCE(e.on_hand, 0)) / 2.0, 2
    )                                                       AS avg_inventory,
    -- 庫存變化方向
    CASE
        WHEN e.on_hand > b.on_hand  THEN 'INCREASED'
        WHEN e.on_hand < b.on_hand  THEN 'DECREASED'
        WHEN e.on_hand = b.on_hand  THEN 'UNCHANGED'
        WHEN b.on_hand IS NULL      THEN 'NEW_ITEM'
        WHEN e.on_hand IS NULL      THEN 'DISAPPEARED'
    END                                                     AS inv_movement
FROM stg.beg_inv b
FULL OUTER JOIN stg.end_inv e USING (inventory_id)
ORDER BY store, brand
LIMIT 30;

-- =============================================
-- Module 6c: 採購前置時間分佈（Lead Time）
-- =============================================
SELECT
    MIN(receiving_date - po_date)                           AS min_lead_days,
    PERCENTILE_CONT(0.25) WITHIN GROUP
        (ORDER BY receiving_date - po_date)                 AS p25_lead_days,
    PERCENTILE_CONT(0.50) WITHIN GROUP
        (ORDER BY receiving_date - po_date)                 AS p50_lead_days,
    ROUND(AVG(receiving_date - po_date), 2)                 AS avg_lead_days,
    PERCENTILE_CONT(0.75) WITHIN GROUP
        (ORDER BY receiving_date - po_date)                 AS p75_lead_days,
    PERCENTILE_CONT(0.95) WITHIN GROUP
        (ORDER BY receiving_date - po_date)                 AS p95_lead_days,
    MAX(receiving_date - po_date)                           AS max_lead_days,
    ROUND(STDDEV(receiving_date - po_date)::numeric, 2)     AS stddev_lead_days
FROM stg.purchases
WHERE receiving_date >= po_date;   -- 排除邏輯錯誤資料

-- =============================================
-- Module 6d: Reorder Point 前置計算（依品牌）
-- 公式：ROP = (平均日銷量 × 平均前置天數) + 安全庫存
-- 安全庫存 = Z × σ_demand × √Lead Time  (此處先計算基礎輸入)
-- =============================================
WITH daily_sales AS (
    SELECT
        brand,
        sales_date,
        SUM(sales_quantity)                                 AS daily_qty
    FROM stg.sales
    GROUP BY brand, sales_date
),
sales_stats AS (
    SELECT
        brand,
        ROUND(AVG(daily_qty), 4)                           AS avg_daily_demand,
        ROUND(STDDEV(daily_qty)::numeric, 4)               AS stddev_daily_demand,
        COUNT(DISTINCT sales_date)                         AS selling_days
    FROM daily_sales
    GROUP BY brand
),
lead_stats AS (
    SELECT
        brand,
        ROUND(AVG(receiving_date - po_date)::numeric, 2)  AS avg_lead_days,
        ROUND(STDDEV(receiving_date - po_date)::numeric, 2) AS stddev_lead_days
    FROM stg.purchases
    WHERE receiving_date >= po_date
    GROUP BY brand
)
SELECT
    ss.brand,
    ss.avg_daily_demand,
    ss.stddev_daily_demand,
    ss.selling_days,
    ls.avg_lead_days,
    ls.stddev_lead_days,
    -- ROP（不含安全庫存）
    ROUND(ss.avg_daily_demand * COALESCE(ls.avg_lead_days, 7), 2)  AS rop_base,
    -- 安全庫存（Z=1.645 → 95% service level）
    ROUND(1.645 * ss.stddev_daily_demand
        * SQRT(COALESCE(ls.avg_lead_days, 7)), 2)                  AS safety_stock_95,
    -- 完整 ROP
    ROUND(
        ss.avg_daily_demand * COALESCE(ls.avg_lead_days, 7)
        + 1.645 * ss.stddev_daily_demand
          * SQRT(COALESCE(ls.avg_lead_days, 7)), 2
    )                                                              AS rop_with_safety_stock
FROM sales_stats ss
LEFT JOIN lead_stats ls USING (brand)
ORDER BY rop_with_safety_stock DESC
LIMIT 20;