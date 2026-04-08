-- =============================================
-- Module 3a: 門店 & 城市分佈
-- =============================================
SELECT
    COUNT(DISTINCT store)        AS distinct_stores,
    COUNT(DISTINCT city)         AS distinct_cities
FROM stg.beg_inv;

-- =============================================
-- Module 3b: 品牌 & 商品描述數
-- =============================================
SELECT
    COUNT(DISTINCT brand)        AS distinct_brands,
    COUNT(DISTINCT description)  AS distinct_descriptions,
    COUNT(DISTINCT size)         AS distinct_sizes
FROM stg.purchase_prices;

-- =============================================
-- Module 3c: 供應商數（三表對比，單一輸出）
-- =============================================
SELECT 'stg.purchases'         AS source, COUNT(DISTINCT vendor_number) AS vendor_cnt FROM stg.purchases
UNION ALL
SELECT 'stg.invoice_purchases',            COUNT(DISTINCT vendor_number)               FROM stg.invoice_purchases
UNION ALL
SELECT 'stg.sales',                        COUNT(DISTINCT vendor_no)                   FROM stg.sales
ORDER BY source;

-- =============================================
-- Module 3d: Classification 分類分佈（purchase_prices 主檔）
-- =============================================
SELECT
    classification,
    COUNT(*)                     AS brand_count,
    ROUND(COUNT(*) * 100.0
        / SUM(COUNT(*)) OVER (), 2) AS pct
FROM stg.purchase_prices
GROUP BY classification
ORDER BY brand_count DESC;

-- =============================================
-- Module 3e: 各門市銷售前 10 品牌（按銷售金額）— 修正版
-- =============================================
WITH brand_sales AS (
    SELECT
        store,
        brand,
        SUM(sales_dollars)  AS total_revenue,
        SUM(sales_quantity) AS total_qty
    FROM stg.sales
    GROUP BY store, brand
),
ranked AS (
    SELECT
        store,
        brand,
        total_revenue,
        total_qty,
        RANK() OVER (PARTITION BY store ORDER BY total_revenue DESC) AS rank_in_store
    FROM brand_sales
)
SELECT *
FROM ranked
WHERE rank_in_store <= 10
ORDER BY store, rank_in_store;