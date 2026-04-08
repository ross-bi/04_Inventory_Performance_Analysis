-- =============================================
-- Module 1: Row Counts & Date Range
-- =============================================
SELECT
    -- 各表行數
    (SELECT COUNT(*) FROM stg.beg_inv)            AS beg_inv_rows,
    (SELECT COUNT(*) FROM stg.end_inv)            AS end_inv_rows,
    (SELECT COUNT(*) FROM stg.purchases)          AS purchases_rows,
    (SELECT COUNT(*) FROM stg.invoice_purchases)  AS invoice_purchases_rows,
    (SELECT COUNT(*) FROM stg.sales)              AS sales_rows,
    (SELECT COUNT(*) FROM stg.purchase_prices)    AS purchase_prices_rows,
    -- 銷售時間範圍
    (SELECT MIN(sales_date) FROM stg.sales)             AS sales_start,
    (SELECT MAX(sales_date) FROM stg.sales)             AS sales_end,
    (SELECT COUNT(DISTINCT sales_date) FROM stg.sales)  AS distinct_sale_days,
    -- 採購時間範圍
    (SELECT MIN(po_date)         FROM stg.purchases)    AS po_start,
    (SELECT MAX(po_date)         FROM stg.purchases)    AS po_end,
    (SELECT MIN(receiving_date)  FROM stg.purchases)    AS recv_start,
    (SELECT MAX(receiving_date)  FROM stg.purchases)    AS recv_end;