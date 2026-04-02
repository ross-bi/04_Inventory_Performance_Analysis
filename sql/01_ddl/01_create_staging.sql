-- =============================================================
-- 01_create_staging.sql
-- Creates all staging (raw load) tables for Inventory Analysis
-- =============================================================

CREATE SCHEMA IF NOT EXISTS staging;

-- ------------------------------------------------------------
-- stg_beg_inventory  (BegInvFINAL12312016)
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
    start_date    DATE
);

-- ------------------------------------------------------------
-- stg_end_inventory  (EndInvFINAL12312016)
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
    end_date      DATE
);

-- ------------------------------------------------------------
-- stg_sales  (SalesFINAL12312016)
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
    sales_date      DATE,
    volume          INT,
    classification  INT,
    excise_tax      NUMERIC(8,2),
    vendor_no       INT,
    vendor_name     VARCHAR(100)
);

-- ------------------------------------------------------------
-- stg_purchases  (PurchasesFINAL12312016)
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
    po_date         DATE,
    receiving_date  DATE,
    invoice_date    DATE,
    pay_date        DATE,
    purchase_price  NUMERIC(10,2),
    quantity        INT,
    dollars         NUMERIC(12,2),
    classification  INT
);

-- ------------------------------------------------------------
-- stg_invoice_purchases  (InvoicePurchases12312016)
-- ------------------------------------------------------------
DROP TABLE IF EXISTS staging.stg_invoice_purchases CASCADE;
CREATE TABLE staging.stg_invoice_purchases (
    vendor_number  INT,
    vendor_name    VARCHAR(100),
    invoice_date   DATE,
    po_number      INT,
    po_date        DATE,
    pay_date       DATE,
    quantity       INT,
    dollars        NUMERIC(12,2),
    freight        NUMERIC(10,2),
    approval       VARCHAR(20)
);

-- ------------------------------------------------------------
-- stg_purchase_prices  (2017PurchasePricesDec)
-- ------------------------------------------------------------
DROP TABLE IF EXISTS staging.stg_purchase_prices CASCADE;
CREATE TABLE staging.stg_purchase_prices (
    brand_id        INT,
    description     VARCHAR(200),
    price           NUMERIC(10,2),
    size            VARCHAR(30),
    volume          VARCHAR(20),   -- stored as text in source (e.g. "750")
    classification  INT,
    purchase_price  NUMERIC(10,2),
    vendor_number   INT,
    vendor_name     VARCHAR(100)
);
