-- =============================================
-- Module 2a: stg.sales NULL 掃描
-- =============================================
SELECT
    COUNT(*)                                               AS total_rows,
    COUNT(*) FILTER (WHERE inventory_id  IS NULL)          AS null_inventory_id,
    COUNT(*) FILTER (WHERE store         IS NULL)          AS null_store,
    COUNT(*) FILTER (WHERE brand         IS NULL)          AS null_brand,
    COUNT(*) FILTER (WHERE sales_quantity IS NULL)         AS null_qty,
    COUNT(*) FILTER (WHERE sales_dollars  IS NULL)         AS null_dollars,
    COUNT(*) FILTER (WHERE sales_price    IS NULL)         AS null_price,
    COUNT(*) FILTER (WHERE sales_date     IS NULL)         AS null_date,
    COUNT(*) FILTER (WHERE vendor_no      IS NULL)         AS null_vendor_no,
    COUNT(*) FILTER (WHERE vendor_name    IS NULL)         AS null_vendor_name,
    COUNT(*) FILTER (WHERE classification IS NULL)         AS null_classification,
    COUNT(*) FILTER (WHERE excise_tax     IS NULL)         AS null_excise_tax
FROM stg.sales;

-- =============================================
-- Module 2b: stg.purchases NULL 掃描
-- =============================================
SELECT
    COUNT(*)                                                AS total_rows,
    COUNT(*) FILTER (WHERE inventory_id    IS NULL)         AS null_inventory_id,
    COUNT(*) FILTER (WHERE store           IS NULL)         AS null_store,
    COUNT(*) FILTER (WHERE vendor_number   IS NULL)         AS null_vendor_number,
    COUNT(*) FILTER (WHERE po_date         IS NULL)         AS null_po_date,
    COUNT(*) FILTER (WHERE receiving_date  IS NULL)         AS null_recv_date,
    COUNT(*) FILTER (WHERE invoice_date    IS NULL)         AS null_invoice_date,
    COUNT(*) FILTER (WHERE pay_date        IS NULL)         AS null_pay_date,
    COUNT(*) FILTER (WHERE purchase_price  IS NULL)         AS null_purchase_price,
    COUNT(*) FILTER (WHERE quantity        IS NULL)         AS null_qty,
    COUNT(*) FILTER (WHERE dollars         IS NULL)         AS null_dollars,
    COUNT(*) FILTER (WHERE classification  IS NULL)         AS null_classification
FROM stg.purchases;

-- =============================================
-- Module 2c: stg.beg_inv / stg.end_inv NULL 掃描（合併一行輸出）
-- =============================================
SELECT
    'beg_inv'                                              AS source_table,
    COUNT(*)                                               AS total_rows,
    COUNT(*) FILTER (WHERE inventory_id IS NULL)           AS null_inventory_id,
    COUNT(*) FILTER (WHERE on_hand      IS NULL)           AS null_on_hand,
    COUNT(*) FILTER (WHERE price        IS NULL)           AS null_price,
    COUNT(*) FILTER (WHERE city         IS NULL)           AS null_city,
    COUNT(*) FILTER (WHERE start_date   IS NULL)           AS null_date
FROM stg.beg_inv
UNION ALL
SELECT
    'end_inv',
    COUNT(*),
    COUNT(*) FILTER (WHERE inventory_id IS NULL),
    COUNT(*) FILTER (WHERE on_hand      IS NULL),
    COUNT(*) FILTER (WHERE price        IS NULL),
    COUNT(*) FILTER (WHERE city         IS NULL),
    COUNT(*) FILTER (WHERE end_date     IS NULL)
FROM stg.end_inv;

-- =============================================
-- Module 2d: stg.purchase_prices NULL 掃描
-- =============================================
SELECT
    COUNT(*)                                               AS total_rows,
    COUNT(*) FILTER (WHERE brand          IS NULL)         AS null_brand,
    COUNT(*) FILTER (WHERE description    IS NULL)         AS null_description,
    COUNT(*) FILTER (WHERE price          IS NULL)         AS null_price,
    COUNT(*) FILTER (WHERE purchase_price IS NULL)         AS null_purchase_price,
    COUNT(*) FILTER (WHERE vendor_number  IS NULL)         AS null_vendor_number,
    COUNT(*) FILTER (WHERE volume         IS NULL)         AS null_volume,
    COUNT(*) FILTER (WHERE classification IS NULL)         AS null_classification
FROM stg.purchase_prices;