-- =============================================================
-- 00_schema_setup.sql
-- Project : 04 Inventory Performance Analysis
-- Purpose : Create database schemas and raw tables
-- Run     : Once, before loading any data
-- =============================================================

-- ------------------------------------------------------------
-- 1. Schemas
-- ------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS staging;
CREATE SCHEMA IF NOT EXISTS marts;

-- ------------------------------------------------------------
-- 2. Raw Tables  (mirror of CSV columns, all TEXT for safe load)
-- ------------------------------------------------------------

DROP TABLE IF EXISTS raw.raw_sales CASCADE;
CREATE TABLE raw.raw_sales (
    inventory_id      TEXT,
    store             TEXT,
    brand             TEXT,
    description       TEXT,
    size              TEXT,
    sales_quantity    TEXT,
    sales_dollars     TEXT,
    sales_price       TEXT,
    sales_date        TEXT,
    volume            TEXT,
    classification    TEXT,
    excise_tax        TEXT,
    vendor_no         TEXT,
    vendor_name       TEXT
);

DROP TABLE IF EXISTS raw.raw_purchases CASCADE;
CREATE TABLE raw.raw_purchases (
    inventory_id      TEXT,
    store             TEXT,
    brand             TEXT,
    vendor_number     TEXT,
    po_number         TEXT,
    po_date           TEXT,
    receiving_date    TEXT,
    invoice_date      TEXT,
    pay_date          TEXT,
    quantity          TEXT,
    dollars           TEXT,
    freight           TEXT,
    volume            TEXT
);

DROP TABLE IF EXISTS raw.raw_beg_inventory CASCADE;
CREATE TABLE raw.raw_beg_inventory (
    inventory_id      TEXT,
    store             TEXT,
    brand             TEXT,
    description       TEXT,
    size              TEXT,
    on_hand           TEXT,
    price             TEXT,
    start_date        TEXT
);

DROP TABLE IF EXISTS raw.raw_end_inventory CASCADE;
CREATE TABLE raw.raw_end_inventory (
    inventory_id      TEXT,
    store             TEXT,
    brand             TEXT,
    description       TEXT,
    size              TEXT,
    on_hand           TEXT,
    price             TEXT,
    end_date          TEXT
);

DROP TABLE IF EXISTS raw.raw_invoice_purchases CASCADE;
CREATE TABLE raw.raw_invoice_purchases (
    vendor_number     TEXT,
    vendor_name       TEXT,
    invoice_date      TEXT,
    po_number         TEXT,
    po_date           TEXT,
    pay_date          TEXT,
    quantity          TEXT,
    dollars           TEXT,
    freight           TEXT,
    approval          TEXT
);

DROP TABLE IF EXISTS raw.raw_purchase_prices CASCADE;
CREATE TABLE raw.raw_purchase_prices (
    brand             TEXT,
    description       TEXT,
    price             TEXT,
    size              TEXT,
    volume            TEXT,
    classification    TEXT,
    purchase_price    TEXT,
    vendor_no         TEXT,
    vendor_name       TEXT
);

-- ------------------------------------------------------------
-- 3. Audit log table (tracks each load run)
-- ------------------------------------------------------------
DROP TABLE IF EXISTS raw.load_audit CASCADE;
CREATE TABLE raw.load_audit (
    audit_id        SERIAL PRIMARY KEY,
    table_name      TEXT        NOT NULL,
    rows_loaded     INT,
    loaded_at       TIMESTAMP   DEFAULT NOW(),
    source_file     TEXT,
    notes           TEXT
);

SELECT 'Schema setup complete ✅' AS status;
