-- ============================================================
-- FILE: sql/02_elt/01_load_raw.sql
-- PURPOSE: Load CSV files into raw schema using PostgreSQL COPY
-- USAGE:   Run from psql: \i sql/02_elt/01_load_raw.sql
-- NOTE:    Replace /path/to/data/raw/ with your local folder path
-- UPDATED: 2026-04-10 v3 - fix invoice_purchases column list to
--          match true CSV order; approval as TEXT
-- ============================================================

-- Truncate before reload (idempotent)
TRUNCATE TABLE raw.sales;
TRUNCATE TABLE raw.purchases;
TRUNCATE TABLE raw.beg_inventory;
TRUNCATE TABLE raw.end_inventory;
TRUNCATE TABLE raw.invoice_purchases;
TRUNCATE TABLE raw.purchase_prices;

-- ---------------------------------------------------------
-- 1. Sales
-- ---------------------------------------------------------
COPY raw.sales (
    inventory_id, store, brand, description, size,
    sales_quantity, sales_dollars, sales_price, sales_date,
    volume, classification, excise_tax, vendor_no, vendor_name
)
FROM 'C:/Program Files/PostgreSQL/18/data/pwc_stock/SalesFINAL12312016.csv'
WITH (
    FORMAT CSV,
    HEADER TRUE,
    QUOTE '"',
    NULL ''
);

-- ---------------------------------------------------------
-- 2. Purchases
-- ---------------------------------------------------------
COPY raw.purchases (
    inventory_id, store, brand, description, size,
    vendor_number, vendor_name, po_number, po_date,
    receiving_date, invoice_date, pay_date,
    purchase_price, quantity, dollars, classification
)
FROM 'C:/Program Files/PostgreSQL/18/data/pwc_stock/PurchasesFINAL12312016.csv'
WITH (
    FORMAT CSV,
    HEADER TRUE,
    QUOTE '"',
    NULL ''
);

-- ---------------------------------------------------------
-- 3. Beginning Inventory
-- ---------------------------------------------------------
COPY raw.beg_inventory (
    inventory_id, store, city, brand, description,
    size, on_hand, price, start_date
)
FROM 'C:/Program Files/PostgreSQL/18/data/pwc_stock/BegInvFINAL12312016.csv'
WITH (
    FORMAT CSV,
    HEADER TRUE,
    QUOTE '"',
    NULL ''
);

-- ---------------------------------------------------------
-- 4. Ending Inventory
-- ---------------------------------------------------------
COPY raw.end_inventory (
    inventory_id, store, city, brand, description,
    size, on_hand, price, end_date
)
FROM 'C:/Program Files/PostgreSQL/18/data/pwc_stock/EndInvFINAL12312016.csv'
WITH (
    FORMAT CSV,
    HEADER TRUE,
    QUOTE '"',
    NULL ''
);

-- ---------------------------------------------------------
-- 5. Invoice Purchases
-- TRUE CSV column order (verified from header):
--   vendor_number, vendor_name, invoice_date, po_number,
--   po_date, pay_date, quantity, dollars, freight, approval
-- ---------------------------------------------------------
COPY raw.invoice_purchases (
    vendor_number, vendor_name, invoice_date, po_number,
    po_date, pay_date, quantity, dollars, freight, approval
)
FROM 'C:/Program Files/PostgreSQL/18/data/pwc_stock/InvoicePurchases12312016.csv'
WITH (
    FORMAT CSV,
    HEADER TRUE,
    QUOTE '"',
    NULL ''
);

-- ---------------------------------------------------------
-- 6. Purchase Prices (2017 reference)
-- ---------------------------------------------------------
COPY raw.purchase_prices (
    brand, description, price, size, volume,
    classification, purchase_price, vendor_number, vendor_name
)
FROM 'C:/Program Files/PostgreSQL/18/data/pwc_stock/2017PurchasePricesDec.csv'
WITH (
    FORMAT CSV,
    HEADER TRUE,
    QUOTE '"',
    NULL ''
);

-- ---------------------------------------------------------
-- Verification: row count per table
-- ---------------------------------------------------------
SELECT 'raw.sales'               AS table_name, COUNT(*) AS row_count FROM raw.sales
UNION ALL
SELECT 'raw.purchases',           COUNT(*) FROM raw.purchases
UNION ALL
SELECT 'raw.beg_inventory',       COUNT(*) FROM raw.beg_inventory
UNION ALL
SELECT 'raw.end_inventory',       COUNT(*) FROM raw.end_inventory
UNION ALL
SELECT 'raw.invoice_purchases',   COUNT(*) FROM raw.invoice_purchases
UNION ALL
SELECT 'raw.purchase_prices',     COUNT(*) FROM raw.purchase_prices
ORDER BY table_name;
