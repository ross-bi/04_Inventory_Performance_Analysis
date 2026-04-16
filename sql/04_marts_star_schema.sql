-- =============================================================================
-- Phase 4: Marts Layer - Star Schema
-- Project: 04_Inventory_Performance_Analysis
-- Description: Create analytical dimensions and fact tables using Surrogate Keys
--
-- ABC Classification Strategy (Portfolio Highlight):
--   Problem : Power BI cannot efficiently compute running-total ABC on 12M rows.
--   Solution: "Static ABC" -- classify once in PostgreSQL, store on dim_product.
--   Method  : After fact_sales is loaded, aggregate revenue per product, compute
--             cumulative % via window function, then back-fill abc_class with a
--             single UPDATE ... FROM CTE pass.  This breaks the Fact/Dim circular
--             dependency because dim_product is written BEFORE fact_sales is
--             created, but the abc_class column is populated AFTER fact_sales
--             exists -- a clean two-phase approach.
--   Thresholds : A = top 80 % cumulative revenue
--                B = next 15 % (80-95 %)
--                C = tail  5 % (> 95 %)
-- =============================================================================

DROP TABLE IF EXISTS marts.fact_inventory_snapshot;
DROP TABLE IF EXISTS marts.fact_sales;
DROP TABLE IF EXISTS marts.dim_product;
DROP TABLE IF EXISTS marts.dim_vendor;
DROP TABLE IF EXISTS marts.dim_store;

-- ─────────────────────────────────────────────────────────
-- 1. DIMENSION: dim_vendor
-- ─────────────────────────────────────────────────────────
CREATE TABLE marts.dim_vendor AS
SELECT 
    ROW_NUMBER() OVER(ORDER BY vendor_number) AS vendor_sk,
    vendor_number,
    MAX(vendor_name) AS vendor_name  
FROM (
    SELECT vendor_number, vendor_name FROM staging.stg_purchases WHERE vendor_number IS NOT NULL
    UNION
    SELECT vendor_number, vendor_name FROM staging.stg_sales WHERE vendor_number IS NOT NULL
    UNION
    SELECT vendor_number, vendor_name FROM staging.stg_invoice_purchases WHERE vendor_number IS NOT NULL
    UNION
    SELECT vendor_number, vendor_name FROM staging.stg_purchase_prices WHERE vendor_number IS NOT NULL
) all_vendors
GROUP BY vendor_number;

CREATE UNIQUE INDEX idx_dim_vendor_sk ON marts.dim_vendor (vendor_sk);
CREATE INDEX idx_dim_vendor_number    ON marts.dim_vendor (vendor_number);

-- ─────────────────────────────────────────────────────────
-- 2. DIMENSION: dim_store
-- ─────────────────────────────────────────────────────────
CREATE TABLE marts.dim_store AS
SELECT 
    ROW_NUMBER() OVER(ORDER BY store) AS store_sk,
    store AS store_number,
    MAX(city) AS city
FROM (
    SELECT store, city FROM staging.stg_beg_inventory WHERE store IS NOT NULL
    UNION
    SELECT store, city FROM staging.stg_end_inventory WHERE store IS NOT NULL
    UNION
    SELECT store, NULL AS city FROM staging.stg_sales WHERE store IS NOT NULL
) all_stores
GROUP BY store;

CREATE UNIQUE INDEX idx_dim_store_sk     ON marts.dim_store (store_sk);
CREATE INDEX idx_dim_store_number        ON marts.dim_store (store_number);

-- ─────────────────────────────────────────────────────────
-- 3. DIMENSION: dim_product
--    Note: abc_class column is intentionally NULL at creation time.
--    It will be back-filled in Step 6 after fact_sales is loaded.
-- ─────────────────────────────────────────────────────────
CREATE TABLE marts.dim_product AS
SELECT 
    ROW_NUMBER() OVER(ORDER BY COALESCE(p.brand, s.brand)) AS product_sk,
    COALESCE(p.brand, s.brand)                              AS brand,
    MAX(COALESCE(p.description, s.description))             AS description,
    MAX(COALESCE(p.size, s.size))                           AS size,
    MAX(COALESCE(p.volume_ml, s.volume_ml))                 AS volume_ml,
    MAX(COALESCE(p.classification, s.classification))       AS classification,
    MAX(p.retail_price)                                     AS default_retail_price,
    MAX(p.purchase_price)                                   AS default_cost_price,
    MAX(p.gross_margin_pct)                                 AS default_gross_margin_pct,

    -- ABC placeholder: populated after fact_sales load (see Step 6)
    NULL::VARCHAR(1)                                        AS abc_class

FROM staging.stg_purchase_prices p
FULL OUTER JOIN (
    SELECT 
        brand, 
        MAX(description)    AS description, 
        MAX(size)           AS size, 
        MAX(volume_ml)      AS volume_ml, 
        MAX(classification) AS classification 
    FROM staging.stg_sales 
    WHERE brand IS NOT NULL
    GROUP BY brand
) s ON p.brand = s.brand
GROUP BY COALESCE(p.brand, s.brand);

CREATE UNIQUE INDEX idx_dim_product_sk    ON marts.dim_product (product_sk);
CREATE INDEX        idx_dim_product_brand ON marts.dim_product (brand);

-- ─────────────────────────────────────────────────────────
-- 4. FACT: fact_sales
-- ─────────────────────────────────────────────────────────
CREATE TABLE marts.fact_sales AS
SELECT 
    dp.product_sk,
    ds.store_sk,
    dv.vendor_sk,
    s.inventory_id,
    s.sales_date,
    s.sales_quantity,
    s.sales_price,
    s.sales_dollars,
    s.excise_tax,
    (s.sales_quantity * COALESCE(dp.default_cost_price, 0)) AS estimated_cogs
FROM staging.stg_sales s
LEFT JOIN marts.dim_product dp ON s.brand = dp.brand
LEFT JOIN marts.dim_store ds   ON s.store = ds.store_number
LEFT JOIN marts.dim_vendor dv  ON s.vendor_number = dv.vendor_number;

CREATE INDEX idx_fact_sales_product_sk ON marts.fact_sales(product_sk);
CREATE INDEX idx_fact_sales_date       ON marts.fact_sales(sales_date);

-- ─────────────────────────────────────────────────────────
-- 5. FACT: fact_inventory_snapshot
-- ─────────────────────────────────────────────────────────
CREATE TABLE marts.fact_inventory_snapshot AS
SELECT 
    dp.product_sk,
    ds.store_sk,
    b.inventory_id,
    b.start_date        AS snapshot_date,
    'BEGINNING'         AS snapshot_type,
    b.on_hand           AS quantity_on_hand,
    b.price             AS snapshot_price,
    (b.on_hand * b.price) AS total_inventory_value
FROM staging.stg_beg_inventory b
LEFT JOIN marts.dim_product dp ON b.brand = dp.brand
LEFT JOIN marts.dim_store ds   ON b.store = ds.store_number

UNION ALL

SELECT 
    dp.product_sk,
    ds.store_sk,
    e.inventory_id,
    e.end_date          AS snapshot_date,
    'ENDING'            AS snapshot_type,
    e.on_hand           AS quantity_on_hand,
    e.price             AS snapshot_price,
    (e.on_hand * e.price) AS total_inventory_value
FROM staging.stg_end_inventory e
LEFT JOIN marts.dim_product dp ON e.brand = dp.brand
LEFT JOIN marts.dim_store ds   ON e.store = ds.store_number;

CREATE INDEX idx_fact_inv_product_sk ON marts.fact_inventory_snapshot(product_sk);
CREATE INDEX idx_fact_inv_date       ON marts.fact_inventory_snapshot(snapshot_date);

-- ─────────────────────────────────────────────────────────
-- 6. STATIC ABC CLASSIFICATION  (runs AFTER fact_sales is loaded)
--
--    Two-phase logic to avoid Fact/Dim circular dependency:
--      Phase A -- Aggregate total revenue per product from fact_sales
--      Phase B -- Compute running cumulative % with SUM() OVER()
--      Phase C -- Assign A / B / C label, then UPDATE dim_product
--
--    Thresholds (Pareto-based, industry standard):
--      A : cumulative revenue <= 80 %   (high-value, tight control)
--      B : cumulative revenue <= 95 %   (moderate value)
--      C : cumulative revenue >  95 %   (low-value / long-tail)
-- ─────────────────────────────────────────────────────────
WITH

-- Phase A: total revenue per product across all stores & dates
product_revenue AS (
    SELECT
        product_sk,
        SUM(sales_dollars) AS total_sales_dollars
    FROM marts.fact_sales
    WHERE sales_dollars IS NOT NULL
    GROUP BY product_sk
),

-- Phase B: running cumulative revenue percentage
--   ORDER BY revenue DESC so highest-value products accumulate first
running_total AS (
    SELECT
        product_sk,
        total_sales_dollars,
        SUM(total_sales_dollars) OVER ()                                           AS grand_total,
        SUM(total_sales_dollars) OVER (ORDER BY total_sales_dollars DESC
                                       ROWS BETWEEN UNBOUNDED PRECEDING
                                                AND CURRENT ROW)                   AS cumulative_sales,
        ROUND(
            100.0 * SUM(total_sales_dollars) OVER (ORDER BY total_sales_dollars DESC
                                                   ROWS BETWEEN UNBOUNDED PRECEDING
                                                            AND CURRENT ROW)
            / NULLIF(SUM(total_sales_dollars) OVER (), 0),
            4
        )                                                                           AS cumulative_pct
    FROM product_revenue
),

-- Phase C: assign ABC label based on cumulative percentage
abc_labels AS (
    SELECT
        product_sk,
        cumulative_pct,
        CASE
            WHEN cumulative_pct <= 80  THEN 'A'
            WHEN cumulative_pct <= 95  THEN 'B'
            ELSE                            'C'
        END AS abc_class
    FROM running_total
)

-- Phase D: back-fill dim_product in a single UPDATE pass
UPDATE marts.dim_product dp
SET    abc_class = al.abc_class
FROM   abc_labels al
WHERE  dp.product_sk = al.product_sk;

-- ─────────────────────────────────────────────────────────
-- 7. VERIFICATION QUERY  (run manually to inspect distribution)
--
--    Expected result (Pareto rule of thumb):
--      A -- ~10-20 % of SKUs drive 80 % of revenue
--      B -- ~20-30 % of SKUs
--      C -- ~50-70 % of SKUs (long tail)
-- ─────────────────────────────────────────────────────────
-- SELECT
--     abc_class,
--     COUNT(*)                                              AS sku_count,
--     ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(), 2)    AS sku_pct,
--     ROUND(SUM(default_retail_price), 2)                  AS sample_value  -- proxy only
-- FROM marts.dim_product
-- GROUP BY abc_class
-- ORDER BY abc_class;
