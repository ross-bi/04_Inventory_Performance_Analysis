-- ============================================================
-- FILE: sql/01_ddl/01_create_raw_tables.sql
-- PURPOSE: Layer 1 - Raw Ingestion Tables (1:1 mapping to CSV)
-- SOURCE: PwC x Kaggle Inventory Analysis Case Study
-- AUTHOR: ross-bi
-- UPDATED: 2026-04-10
--   v2: volume NUMERIC(8,2) - CSV contains decimal mL values
--   v3: invoice_purchases column order corrected to match CSV;
--       approval stored as TEXT (values: 'None' / approver name)
--       purchase_prices: added vendor_number, vendor_name columns
-- ============================================================

CREATE SCHEMA IF NOT EXISTS raw;

-- ---------------------------------------------------------
-- 1. raw.sales
-- Source: SalesFINAL12312016.csv
-- Columns: inventory_id, store, brand, description, size,
--          sales_quantity, sales_dollars, sales_price,
--          sales_date, volume, classification, excise_tax,
--          vendor_no, vendor_name
-- ---------------------------------------------------------
DROP TABLE IF EXISTS raw.sales;
CREATE TABLE raw.sales (
    inventory_id     TEXT,
    store            INTEGER,
    brand            INTEGER,
    description      TEXT,
    size             TEXT,
    sales_quantity   INTEGER,
    sales_dollars    NUMERIC(12,2),
    sales_price      NUMERIC(10,2),
    sales_date       DATE,
    volume           NUMERIC(8,2),   -- DECIMAL: raw data has fractional mL (e.g. 162.5)
    classification   INTEGER,        -- 1=Spirits, 2=Wine, 3=Beer
    excise_tax       NUMERIC(10,2),
    vendor_no        INTEGER,
    vendor_name      TEXT,
    _loaded_at       TIMESTAMP NOT NULL DEFAULT NOW()
);

-- ---------------------------------------------------------
-- 2. raw.purchases
-- Source: PurchasesFINAL12312016.csv
-- Columns: inventory_id, store, brand, description, size,
--          vendor_number, vendor_name, po_number, po_date,
--          receiving_date, invoice_date, pay_date,
--          purchase_price, quantity, dollars, classification
-- ---------------------------------------------------------
DROP TABLE IF EXISTS raw.purchases;
CREATE TABLE raw.purchases (
    inventory_id     TEXT,
    store            INTEGER,
    brand            INTEGER,
    description      TEXT,
    size             TEXT,
    vendor_number    INTEGER,
    vendor_name      TEXT,
    po_number        TEXT,
    po_date          DATE,
    receiving_date   DATE,
    invoice_date     DATE,
    pay_date         DATE,
    purchase_price   NUMERIC(10,2),
    quantity         INTEGER,
    dollars          NUMERIC(12,2),
    classification   INTEGER,
    _loaded_at       TIMESTAMP NOT NULL DEFAULT NOW()
);

-- ---------------------------------------------------------
-- 3. raw.beg_inventory
-- Source: BegInvFINAL12312016.csv
-- Columns: inventory_id, store, city, brand, description,
--          size, on_hand, price, start_date
-- ---------------------------------------------------------
DROP TABLE IF EXISTS raw.beg_inventory;
CREATE TABLE raw.beg_inventory (
    inventory_id     TEXT,
    store            INTEGER,
    city             TEXT,
    brand            INTEGER,
    description      TEXT,
    size             TEXT,
    on_hand          INTEGER,
    price            NUMERIC(10,2),
    start_date       DATE,
    _loaded_at       TIMESTAMP NOT NULL DEFAULT NOW()
);

-- ---------------------------------------------------------
-- 4. raw.end_inventory
-- Source: EndInvFINAL12312016.csv
-- Columns: inventory_id, store, city, brand, description,
--          size, on_hand, price, end_date
-- ---------------------------------------------------------
DROP TABLE IF EXISTS raw.end_inventory;
CREATE TABLE raw.end_inventory (
    inventory_id     TEXT,
    store            INTEGER,
    city             TEXT,
    brand            INTEGER,
    description      TEXT,
    size             TEXT,
    on_hand          INTEGER,
    price            NUMERIC(10,2),
    end_date         DATE,
    _loaded_at       TIMESTAMP NOT NULL DEFAULT NOW()
);

-- ---------------------------------------------------------
-- 5. raw.invoice_purchases
-- Source: InvoicePurchases12312016.csv
-- TRUE CSV column order (verified from header row):
--   vendor_number, vendor_name, invoice_date, po_number,
--   po_date, pay_date, quantity, dollars, freight, approval
-- NOTE: approval is TEXT - values are 'None' or approver name
-- ---------------------------------------------------------
DROP TABLE IF EXISTS raw.invoice_purchases;
CREATE TABLE raw.invoice_purchases (
    vendor_number    INTEGER,
    vendor_name      TEXT,
    invoice_date     DATE,
    po_number        TEXT,
    po_date          DATE,          -- NOTE: po_date comes AFTER po_number in this CSV
    pay_date         DATE,
    quantity         INTEGER,
    dollars          NUMERIC(12,2),
    freight          NUMERIC(10,2),
    approval         TEXT,          -- 'None' or approver name (e.g. 'Frank Delahunt')
    _loaded_at       TIMESTAMP NOT NULL DEFAULT NOW()
);

-- ---------------------------------------------------------
-- 6. raw.purchase_prices
-- Source: 2017PurchasePricesDec.csv
-- Columns: brand, description, price, size, volume,
--          classification, purchase_price, vendor_number, vendor_name
-- ---------------------------------------------------------
DROP TABLE IF EXISTS raw.purchase_prices;
CREATE TABLE raw.purchase_prices (
    brand            INTEGER,
    description      TEXT,
    price            NUMERIC(10,2),
    size             TEXT,
    volume           NUMERIC(8,2),
    classification   INTEGER,
    purchase_price   NUMERIC(10,2),
    vendor_number    INTEGER,
    vendor_name      TEXT,
    _loaded_at       TIMESTAMP NOT NULL DEFAULT NOW()
);
