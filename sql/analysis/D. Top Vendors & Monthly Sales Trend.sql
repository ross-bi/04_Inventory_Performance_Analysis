-- D1: Top 10 vendors by revenue
SELECT
    dv.vendor_name,
    ROUND(SUM(fs.sales_dollars), 0)   AS total_revenue,
    SUM(fs.sales_quantity)            AS total_units_sold,
    COUNT(DISTINCT fs.product_sk)     AS sku_count
FROM marts.fact_sales fs
JOIN marts.dim_vendor dv ON fs.vendor_sk = dv.vendor_sk
GROUP BY dv.vendor_name
ORDER BY total_revenue DESC
LIMIT 10;

-- D2: Monthly sales trend
SELECT
    DATE_TRUNC('month', sales_date)::DATE   AS sales_month,
    ROUND(SUM(sales_dollars), 0)            AS monthly_revenue,
    SUM(sales_quantity)                     AS monthly_qty,
    COUNT(DISTINCT product_sk)              AS active_skus
FROM marts.fact_sales
GROUP BY 1
ORDER BY 1;

-- D3: Top 10 stores by revenue
SELECT
    ds.city,
    ds.store_number,
    ROUND(SUM(fs.sales_dollars), 0)   AS store_revenue,
    SUM(fs.sales_quantity)            AS store_qty
FROM marts.fact_sales fs
JOIN marts.dim_store ds ON fs.store_sk = ds.store_sk
GROUP BY ds.city, ds.store_number
ORDER BY store_revenue DESC
LIMIT 10;