-- =============================================
-- Module 4a: BegInv ↔ EndInv 匹配率
-- =============================================
SELECT
    COUNT(DISTINCT b.inventory_id)                          AS beg_ids,
    COUNT(DISTINCT e.inventory_id)                          AS end_ids,
    COUNT(DISTINCT b.inventory_id)
        FILTER (WHERE e.inventory_id IS NOT NULL)           AS in_both,
    COUNT(DISTINCT b.inventory_id)
        FILTER (WHERE e.inventory_id IS NULL)               AS beg_only,
    COUNT(DISTINCT e.inventory_id)
        FILTER (WHERE b.inventory_id IS NULL)               AS end_only,
    ROUND(
        COUNT(DISTINCT b.inventory_id)
            FILTER (WHERE e.inventory_id IS NOT NULL)::numeric
        / NULLIF(COUNT(DISTINCT b.inventory_id), 0) * 100, 2
    )                                                       AS beg_match_pct
FROM stg.beg_inv b
FULL OUTER JOIN stg.end_inv e USING (inventory_id);

-- =============================================
-- Module 4b: Sales ↔ BegInv 匹配率（InventoryId 維度）
-- =============================================
SELECT
    COUNT(DISTINCT s.inventory_id)                          AS sales_ids,
    COUNT(DISTINCT s.inventory_id)
        FILTER (WHERE b.inventory_id IS NOT NULL)           AS matched_in_beg,
    COUNT(DISTINCT s.inventory_id)
        FILTER (WHERE b.inventory_id IS NULL)               AS sales_not_in_beg,
    ROUND(
        COUNT(DISTINCT s.inventory_id)
            FILTER (WHERE b.inventory_id IS NOT NULL)::numeric
        / NULLIF(COUNT(DISTINCT s.inventory_id), 0) * 100, 2
    )                                                       AS match_pct
FROM stg.sales s
LEFT JOIN stg.beg_inv b USING (inventory_id);

-- =============================================
-- Module 4c: Purchases ↔ Purchase_Prices 品牌匹配率
-- =============================================
SELECT
    COUNT(DISTINCT p.brand)                                 AS purchase_brands,
    COUNT(DISTINCT p.brand)
        FILTER (WHERE pp.brand IS NOT NULL)                 AS matched_brands,
    COUNT(DISTINCT p.brand)
        FILTER (WHERE pp.brand IS NULL)                     AS unmatched_brands,
    ROUND(
        COUNT(DISTINCT p.brand)
            FILTER (WHERE pp.brand IS NOT NULL)::numeric
        / NULLIF(COUNT(DISTINCT p.brand), 0) * 100, 2
    )                                                       AS brand_match_pct
FROM stg.purchases p
LEFT JOIN stg.purchase_prices pp USING (brand);

-- =============================================
-- Module 4d: Sales ↔ Purchase_Prices 品牌匹配率（KPI 計算關鍵）
-- =============================================
SELECT
    COUNT(DISTINCT s.brand)                                 AS sales_brands,
    COUNT(DISTINCT s.brand)
        FILTER (WHERE pp.brand IS NOT NULL)                 AS matched_brands,
    COUNT(DISTINCT s.brand)
        FILTER (WHERE pp.brand IS NULL)                     AS unmatched_brands,
    ROUND(
        COUNT(DISTINCT s.brand)
            FILTER (WHERE pp.brand IS NOT NULL)::numeric
        / NULLIF(COUNT(DISTINCT s.brand), 0) * 100, 2
    )                                                       AS brand_match_pct,
    -- 未匹配品牌的銷售金額佔比（評估 COGS 估算誤差）
    SUM(s.sales_dollars)
        FILTER (WHERE pp.brand IS NULL)                     AS unmatched_revenue,
    ROUND(
        SUM(s.sales_dollars)
            FILTER (WHERE pp.brand IS NULL)::numeric
        / NULLIF(SUM(s.sales_dollars), 0) * 100, 2
    )                                                       AS unmatched_revenue_pct
FROM stg.sales s
LEFT JOIN stg.purchase_prices pp USING (brand);