-- =============================================================================
-- 04 Inventory Performance Analysis
-- Script 04: Transform & Populate Fact Tables
-- =============================================================================

SET search_path = inventory;


-- fact_inventory_snapshot: Beginning Inventory
INSERT INTO fact_inventory_snapshot (
    date_key, store_key, product_key, period_type,
    on_hand_qty, unit_price, inventory_value
)
SELECT
    TO_CHAR(TO_DATE(s."startDate", 'YYYY-MM-DD'), 'YYYYMMDD')::INT AS date_key,
    st.store_key,
    p.product_key,
    'BEG'                                                          AS period_type,
    s."onHand"                                                     AS on_hand_qty,
    s."Price"                                                      AS unit_price,
    s."onHand" * s."Price"                                         AS inventory_value
FROM staging.stg_beg_inventory s
JOIN dim_store   st ON st.store_id   = s."Store"
JOIN dim_product p  ON p.brand       = s."Brand"::VARCHAR
                    AND p.description = s."Description"
                    AND p.size        = s."Size";


-- fact_inventory_snapshot: Ending Inventory
INSERT INTO fact_inventory_snapshot (
    date_key, store_key, product_key, period_type,
    on_hand_qty, unit_price, inventory_value
)
SELECT
    TO_CHAR(TO_DATE(s."endDate", 'YYYY-MM-DD'), 'YYYYMMDD')::INT   AS date_key,
    st.store_key,
    p.product_key,
    'END'                                                          AS period_type,
    s."onHand"                                                     AS on_hand_qty,
    s."Price"                                                      AS unit_price,
    s."onHand" * s."Price"                                         AS inventory_value
FROM staging.stg_end_inventory s
JOIN dim_store   st ON st.store_id   = s."Store"
JOIN dim_product p  ON p.brand       = s."Brand"::VARCHAR
                    AND p.description = s."Description"
                    AND p.size        = s."Size";


-- fact_purchases: Replenishment records with Lead Time
-- Lead Time = ReceivingDate - Approval date (joined from InvoicePurchases via PONumber)
INSERT INTO fact_purchases (
    receiving_date_key, approval_date_key,
    store_key, product_key, vendor_key,
    purchase_qty, purchase_dollars, purchase_price,
    freight_cost, lead_time_days
)
SELECT
    TO_CHAR(TO_DATE(pur."ReceivingDate", 'YYYY-MM-DD'), 'YYYYMMDD')::INT   AS receiving_date_key,
    CASE
        WHEN inv."Approval" IS NOT NULL
        THEN TO_CHAR(TO_DATE(inv."Approval", 'YYYY-MM-DD'), 'YYYYMMDD')::INT
        ELSE NULL
    END                                                                    AS approval_date_key,
    st.store_key,
    p.product_key,
    v.vendor_key,
    pur."Quantity"                                                         AS purchase_qty,
    pur."Dollars"                                                          AS purchase_dollars,
    CASE
        WHEN pur."Quantity" > 0 THEN ROUND(pur."Dollars" / pur."Quantity", 2)
        ELSE NULL
    END                                                                    AS purchase_price,
    inv."Freight"                                                          AS freight_cost,
    CASE
        WHEN inv."Approval" IS NOT NULL
        THEN TO_DATE(pur."ReceivingDate", 'YYYY-MM-DD')
             - TO_DATE(inv."Approval", 'YYYY-MM-DD')
        ELSE NULL
    END                                                                    AS lead_time_days
FROM staging.stg_purchases pur
JOIN dim_store   st ON st.store_id     = pur."Store"
JOIN dim_product p  ON p.brand         = pur."Brand"::VARCHAR
                    AND p.description   = pur."Description"
                    AND p.size          = pur."Size"
JOIN dim_vendor  v  ON v.vendor_number  = pur."VendorNumber"
LEFT JOIN staging.stg_invoice_purchases inv ON inv."PONumber" = pur."PONumber";


-- fact_sales: Daily sales transactions
INSERT INTO fact_sales (
    date_key, store_key, product_key, vendor_key,
    sales_qty, sales_dollars, sales_price, excise_tax
)
SELECT
    TO_CHAR(TO_DATE(s."SalesDate", 'YYYY-MM-DD'), 'YYYYMMDD')::INT AS date_key,
    st.store_key,
    p.product_key,
    v.vendor_key,
    s."SalesQuantity"                                              AS sales_qty,
    s."SalesDollars"                                               AS sales_dollars,
    s."SalesPrice"                                                 AS sales_price,
    s."ExciseTax"                                                  AS excise_tax
FROM staging.stg_sales s
JOIN dim_store   st ON st.store_id     = s."Store"
JOIN dim_product p  ON p.brand         = s."Brand"::VARCHAR
                    AND p.description   = s."Description"
                    AND p.size          = s."Size"
LEFT JOIN dim_vendor v ON v.vendor_number = s."VendorNo";
