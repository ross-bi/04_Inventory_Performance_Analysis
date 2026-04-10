-- ============================================================
-- FILE: sql/01_ddl/01_create_raw_tables.sql
-- PURPOSE: Layer 1 - Raw Ingestion Tables (1:1 mapping to CSV)
-- SOURCE: PwC x Kaggle Inventory Analysis Case Study
-- AUTHOR: ross-bi
-- DATE: 2026-04-10
-- UPDATED: 2026-04-10 fix volume NUMERIC(8,2) - CSV contains decimals (e.g. 162.5)
-- ============================================================

CREATE SCHEMA IF NOT EXISTS raw;

-- ---------------------------------------------------------
-- 1. raw.sales
-- Source: SalesFINAL12312016.csv
-- Grain: 1 row = 1 sales transaction (store x brand x date)
-- NOTE: volume is NUMERIC(8,2) — raw data contains decimal mL values (e.g. 162.5)
-- ---------------------------------------------------------
DROP TABLE IF EXISTS raw.sales;
CREATE TABLE raw.sales (
    inventory_id     TEXT,           -- Composite key: {store_id}_{store_name}_{brand_id}
    store            INTEGER,
    brand            INTEGER,
    description      TEXT,
    size             TEXT,
    sales_quantity   INTEGER,
    sales_dollars    NUMERIC(12,2),
    sales_price      NUMERIC(10,2),
    sales_date       DATE,
    volume           NUMERIC(8,2),   -- Volume in mL — DECIMAL: raw data has fractional values
    classification   INTEGER,        -- 1=Spirits, 2=Wine, 3=Beer
    excise_tax       NUMERIC(10,2),
    vendor_no        INTEGER,
    vendor_name      TEXT,
    _loaded_at       TIMESTAMP NOT NULL DEFAULT NOW()
);

-- ---------------------------------------------------------
-- 2. raw.purchases
-- Source: PurchasesFINAL12312016.csv
-- Grain: 1 row = 1 purchase order line (store x brand x PO)
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
-- Grain: 1 row = 1 SKU snapshot at period start (2016-01-01)
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
-- Grain: 1 row = 1 SKU snapshot at period end (2016-12-31)
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
-- Grain: 1 row = 1 vendor invoice summary
-- ---------------------------------------------------------
DROP TABLE IF EXISTS raw.invoice_purchases;
CREATE TABLE raw.invoice_purchases (
    vendor_number    INTEGER,
    vendor_name      TEXT,
    invoice_date     DATE,
    po_number        TEXT,
    pay_date         DATE,
    quantity         INTEGER,
    dollars          NUMERIC(12,2),
    freight          NUMERIC(10,2),
    approval_status  TEXT,
    _loaded_at       TIMESTAMP NOT NULL DEFAULT NOW()
);

-- ---------------------------------------------------------
-- 6. raw.purchase_prices
-- Source: 2017PurchasePricesDec.csv
-- Grain: 1 row = 1 SKU reference price (2017 Dec)
-- NOTE: volume NUMERIC(8,2) consistent with raw.sales
-- ---------------------------------------------------------
DROP TABLE IF EXISTS raw.purchase_prices;
CREATE TABLE raw.purchase_prices (
    brand            INTEGER,
    description      TEXT,
    price            NUMERIC(10,2),
    size             TEXT,
    volume           NUMERIC(8,2),   -- Decimal-safe, consistent with raw.sales
    classification   INTEGER,
    purchase_price   NUMERIC(10,2),
    vendor_number    INTEGER,        -- Present in 2017PurchasePricesDec.csv
    vendor_name      TEXT,
    _loaded_at       TIMESTAMP NOT NULL DEFAULT NOW()
);
