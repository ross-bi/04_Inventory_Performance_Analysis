-- =============================================================
-- 01_load_staging.sql
-- COPY commands to load CSV files into staging schema
-- Adjust file paths to match your local environment.
-- =============================================================

-- BEG INVENTORY
COPY staging.stg_beg_inventory (
    inventory_id, store_id, city, brand_id, description,
    size, on_hand, price, start_date
)
FROM '/data/raw/BegInvFINAL12312016.csv'
WITH (FORMAT CSV, HEADER TRUE, QUOTE '"');

-- END INVENTORY
COPY staging.stg_end_inventory (
    inventory_id, store_id, city, brand_id, description,
    size, on_hand, price, end_date
)
FROM '/data/raw/EndInvFINAL12312016.csv'
WITH (FORMAT CSV, HEADER TRUE, QUOTE '"');

-- SALES
COPY staging.stg_sales (
    inventory_id, store_id, brand_id, description, size,
    sales_quantity, sales_dollars, sales_price, sales_date,
    volume, classification, excise_tax, vendor_no, vendor_name
)
FROM '/data/raw/SalesFINAL12312016.csv'
WITH (FORMAT CSV, HEADER TRUE);

-- PURCHASES
COPY staging.stg_purchases (
    inventory_id, store_id, brand_id, description, size,
    vendor_number, vendor_name, po_number, po_date, receiving_date,
    invoice_date, pay_date, purchase_price, quantity, dollars, classification
)
FROM '/data/raw/PurchasesFINAL12312016.csv'
WITH (FORMAT CSV, HEADER TRUE, QUOTE '"');

-- INVOICE PURCHASES
COPY staging.stg_invoice_purchases (
    vendor_number, vendor_name, invoice_date, po_number,
    po_date, pay_date, quantity, dollars, freight, approval
)
FROM '/data/raw/InvoicePurchases12312016.csv'
WITH (FORMAT CSV, HEADER TRUE, QUOTE '"');

-- PURCHASE PRICES (product master)
COPY staging.stg_purchase_prices (
    brand_id, description, price, size, volume,
    classification, purchase_price, vendor_number, vendor_name
)
FROM '/data/raw/2017PurchasePricesDec.csv'
WITH (FORMAT CSV, HEADER TRUE, QUOTE '"');

-- Row count verification
SELECT 'stg_beg_inventory'     AS tbl, COUNT(*) AS rows FROM staging.stg_beg_inventory
UNION ALL
SELECT 'stg_end_inventory',           COUNT(*) FROM staging.stg_end_inventory
UNION ALL
SELECT 'stg_sales',                   COUNT(*) FROM staging.stg_sales
UNION ALL
SELECT 'stg_purchases',               COUNT(*) FROM staging.stg_purchases
UNION ALL
SELECT 'stg_invoice_purchases',       COUNT(*) FROM staging.stg_invoice_purchases
UNION ALL
SELECT 'stg_purchase_prices',         COUNT(*) FROM staging.stg_purchase_prices
ORDER BY tbl;
