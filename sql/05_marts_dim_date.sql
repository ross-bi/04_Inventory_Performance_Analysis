-- 建立 Calendar / Date Spine View（在 PostgreSQL 生成，讓 Power BI 直接匯入）
CREATE OR REPLACE VIEW marts.dim_date AS
SELECT
    gs::DATE                                AS date_key,
    EXTRACT(YEAR FROM gs)::INT              AS year,
    EXTRACT(QUARTER FROM gs)::INT           AS quarter,
    EXTRACT(MONTH FROM gs)::INT             AS month,
    TO_CHAR(gs, 'Month')                    AS month_name,
    EXTRACT(WEEK FROM gs)::INT              AS week_of_year,
    EXTRACT(DOW FROM gs)::INT               AS day_of_week,
    TO_CHAR(gs, 'Day')                      AS day_name,
    (EXTRACT(DOW FROM gs) IN (0, 6))        AS is_weekend
FROM generate_series(
    (SELECT MIN(sales_date) FROM marts.fact_sales),
    (SELECT MAX(sales_date) FROM marts.fact_sales),
    INTERVAL '1 day'
) gs;