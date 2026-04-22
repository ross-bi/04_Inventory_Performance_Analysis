-- C1: ABC distribution
SELECT
    abc_class,
    COUNT(*)                                               AS sku_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(), 2)     AS sku_pct,
    ROUND(AVG(default_gross_margin_pct), 2)                AS avg_gross_margin_pct
FROM marts.dim_product
GROUP BY abc_class
ORDER BY abc_class;

-- C2: Top 10 revenue products (Class A)
SELECT
    dp.brand,
    dp.description,
    dp.abc_class,
    ROUND(SUM(fs.sales_dollars), 0)     AS total_revenue,
    SUM(fs.sales_quantity)              AS total_qty_sold,
    ROUND(AVG(fs.sales_price), 2)       AS avg_selling_price
FROM marts.fact_sales fs
JOIN marts.dim_product dp ON fs.product_sk = dp.product_sk
WHERE dp.abc_class = 'A'
GROUP BY dp.brand, dp.description, dp.abc_class
ORDER BY total_revenue DESC
LIMIT 10;