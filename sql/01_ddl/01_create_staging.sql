-- =============================================================
-- 01_create_staging.sql
-- Creates all staging (raw load) tables for Inventory Analysis
--
-- DATE STRATEGY:
--   All date columns in staging are stored as VARCHAR(20) to
--   accept any source format without DateStyle dependency.
--
--   Source formats observed:
--     BegInvFINAL / EndInvFINAL    : YYYY-MM-DD  (ISO)
--     SalesFINAL                   : M/D/YYYY    (US, e.g. 1/15/2016)
--     PurchasesFINAL               : YYYY-MM-DD  (ISO)
--     InvoicePurchases             : YYYY-MM-DD  (ISO)
--
--   Conversion to DATE / date_key INT happens in
--   sql/03_transform/02_populate_facts.sql using TO_DATE().
-- =============================================================

CREATE SCHEMA IF NOT EXISTS staging;

-- ------------------------------------------------------------
-- stg_beg_inventory  (BegInvFINAL12312016)
-- Dates: start_date  format YYYY-MM-DD
-- ------------------------------------------------------------
DROP TABLE IF EXISTS staging.stg_beg_inventory CASCADE;
CREATE TABLE staging.stg_beg_inventory (
    inventory_id  VARCHAR(60),
    store_id      INT,
    city          VARCHAR(80),
    brand_id      INT,
    description   VARCHAR(200),
    size          VARCHAR(30),
    on_hand       INT,
    price         NUMERIC(10,2),
    start_date    VARCHAR(20)     -- raw: YYYY-MM-DD
);

-- ------------------------------------------------------------
-- stg_end_inventory  (EndInvFINAL12312016)
-- Dates: end_date  format YYYY-MM-DD
-- ------------------------------------------------------------
DROP TABLE IF EXISTS staging.stg_end_inventory CASCADE;
CREATE TABLE staging.stg_end_inventory (
    inventory_id  VARCHAR(60),
    store_id      INT,
    city          VARCHAR(80),
    brand_id      INT,
    description   VARCHAR(200),
    size          VARCHAR(30),
    on_hand       INT,
    price         NUMERIC(10,2),
    end_date      VARCHAR(20)     -- raw: YYYY-MM-DD
);

-- ------------------------------------------------------------
-- stg_sales  (SalesFINAL12312016)
-- Dates: sales_date  format M/D/YYYY  (US style, e.g. 1/15/2016)
-- ------------------------------------------------------------
DROP TABLE IF EXISTS staging.stg_sales CASCADE;
CREATE TABLE staging.stg_sales (
    inventory_id    VARCHAR(60),
    store_id        INT,
    brand_id        INT,
    description     VARCHAR(200),
    size            VARCHAR(30),
    sales_quantity  INT,
    sales_dollars   NUMERIC(12,2),
    sales_price     NUMERIC(10,2),
    sales_date      VARCHAR(20),    -- raw: M/D/YYYY (e.g. 1/15/2016)
    volume          INT,
    classification  INT,
    excise_tax      NUMERIC(8,2),
    vendor_no       INT,
    vendor_name     VARCHAR(100)
);

-- ------------------------------------------------------------
-- stg_purchases  (PurchasesFINAL12312016)
-- Dates: po_date, receiving_date, invoice_date, pay_date  format YYYY-MM-DD
-- ------------------------------------------------------------
DROP TABLE IF EXISTS staging.stg_purchases CASCADE;
CREATE TABLE staging.stg_purchases (
    inventory_id    VARCHAR(60),
    store_id        INT,
    brand_id        INT,
    description     VARCHAR(200),
    size            VARCHAR(30),
    vendor_number   INT,
    vendor_name     VARCHAR(100),
    po_number       INT,
    po_date         VARCHAR(20),    -- raw: YYYY-MM-DD
    receiving_date  VARCHAR(20),    -- raw: YYYY-MM-DD
    invoice_date    VARCHAR(20),    -- raw: YYYY-MM-DD
    pay_date        VARCHAR(20),    -- raw: YYYY-MM-DD
    purchase_price  NUMERIC(10,2),
    quantity        INT,
    dollars         NUMERIC(12,2),
    classification  INT
);

-- ------------------------------------------------------------
-- stg_invoice_purchases  (InvoicePurchases12312016)
-- Dates: invoice_date, po_date, pay_date  format YYYY-MM-DD
-- ------------------------------------------------------------
DROP TABLE IF EXISTS staging.stg_invoice_purchases CASCADE;
CREATE TABLE staging.stg_invoice_purchases (
    vendor_number  INT,
    vendor_name    VARCHAR(100),
    invoice_date   VARCHAR(20),    -- raw: YYYY-MM-DD
    po_number      INT,
    po_date        VARCHAR(20),    -- raw: YYYY-MM-DD
    pay_date       VARCHAR(20),    -- raw: YYYY-MM-DD
    quantity       INT,
    dollars        NUMERIC(12,2),
    freight        NUMERIC(10,2),
    approval       VARCHAR(20)
);

-- ------------------------------------------------------------
-- stg_purchase_prices  (2017PurchasePricesDec)
-- No date columns in this source file.
-- ------------------------------------------------------------
DROP TABLE IF EXISTS staging.stg_purchase_prices CASCADE;
CREATE TABLE staging.stg_purchase_prices (
    brand_id        INT,
    description     VARCHAR(200),
    price           NUMERIC(10,2),
    size            VARCHAR(30),
    volume          VARCHAR(20),   -- e.g. "750" or "1000"
    classification  INT,
    purchase_price  NUMERIC(10,2),
    vendor_number   INT,
    vendor_name     VARCHAR(100)
);
