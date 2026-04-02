-- =============================================================================
-- 04 Inventory Performance Analysis
-- Script 02: Staging Tables & COPY Commands
-- Note: Update file paths to match your local data/raw/ directory
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS staging;


DROP TABLE IF EXISTS staging.stg_beg_inventory;
CREATE TABLE staging.stg_beg_inventory (
    "InventoryId"       VARCHAR(50),
    "Store"             INT,
    "City"              VARCHAR(100),
    "Brand"             INT,
    "Description"       VARCHAR(255),
    "Size"              VARCHAR(50),
    "onHand"            NUMERIC(12,2),
    "Price"             NUMERIC(10,2),
    "startDate"         VARCHAR(30)
);
-- COPY staging.stg_beg_inventory
-- FROM '/absolute/path/to/data/raw/BegInvFINAL12312016.csv'
-- CSV HEADER ENCODING 'UTF8';


DROP TABLE IF EXISTS staging.stg_end_inventory;
CREATE TABLE staging.stg_end_inventory (
    "InventoryId"       VARCHAR(50),
    "Store"             INT,
    "City"              VARCHAR(100),
    "Brand"             INT,
    "Description"       VARCHAR(255),
    "Size"              VARCHAR(50),
    "onHand"            NUMERIC(12,2),
    "Price"             NUMERIC(10,2),
    "endDate"           VARCHAR(30)
);
-- COPY staging.stg_end_inventory
-- FROM '/absolute/path/to/data/raw/EndInvFINAL12312016.csv'
-- CSV HEADER ENCODING 'UTF8';


DROP TABLE IF EXISTS staging.stg_purchases;
CREATE TABLE staging.stg_purchases (
    "InventoryId"       VARCHAR(50),
    "Store"             INT,
    "Brand"             INT,
    "Description"       VARCHAR(255),
    "Size"              VARCHAR(50),
    "VendorNumber"      INT,
    "VendorName"        VARCHAR(200),
    "PONumber"          INT,
    "PODate"            VARCHAR(30),
    "ReceivingDate"     VARCHAR(30),
    "InvoiceDate"       VARCHAR(30),
    "PayDate"           VARCHAR(30),
    "Quantity"          NUMERIC(12,2),
    "Dollars"           NUMERIC(14,2),
    "Classification"    VARCHAR(50)
);
-- COPY staging.stg_purchases
-- FROM '/absolute/path/to/data/raw/PurchasesFINAL12312016.csv'
-- CSV HEADER ENCODING 'UTF8';


DROP TABLE IF EXISTS staging.stg_sales;
CREATE TABLE staging.stg_sales (
    "InventoryId"       VARCHAR(50),
    "Store"             INT,
    "Brand"             INT,
    "Description"       VARCHAR(255),
    "Size"              VARCHAR(50),
    "VendorNo"          INT,
    "VendorName"        VARCHAR(200),
    "Volume"            NUMERIC(8,2),
    "Classification"    VARCHAR(50),
    "SalesQuantity"     NUMERIC(12,2),
    "SalesDollars"      NUMERIC(14,2),
    "SalesPrice"        NUMERIC(10,2),
    "SalesDate"         VARCHAR(30),
    "ExciseTax"         NUMERIC(10,2),
    "County"            INT,
    "City"              VARCHAR(100)
);
-- COPY staging.stg_sales
-- FROM '/absolute/path/to/data/raw/SalesFINAL12312016.csv'
-- CSV HEADER ENCODING 'UTF8';


DROP TABLE IF EXISTS staging.stg_invoice_purchases;
CREATE TABLE staging.stg_invoice_purchases (
    "VendorNumber"      INT,
    "VendorName"        VARCHAR(200),
    "InvoiceDate"       VARCHAR(30),
    "PONumber"          INT,
    "PODate"            VARCHAR(30),
    "PayDate"           VARCHAR(30),
    "Quantity"          NUMERIC(12,2),
    "Dollars"           NUMERIC(14,2),
    "Freight"           NUMERIC(10,2),
    "Approval"          VARCHAR(30)
);
-- COPY staging.stg_invoice_purchases
-- FROM '/absolute/path/to/data/raw/InvoicePurchases12312016.csv'
-- CSV HEADER ENCODING 'UTF8';


DROP TABLE IF EXISTS staging.stg_vendor_prices;
CREATE TABLE staging.stg_vendor_prices (
    "Brand"             INT,
    "Description"       VARCHAR(255),
    "Price"             NUMERIC(10,2),
    "Size"              VARCHAR(50),
    "Volume"            NUMERIC(8,2),
    "Classification"    VARCHAR(50),
    "PurchasePrice"     NUMERIC(10,2),
    "VendorNumber"      INT,
    "VendorName"        VARCHAR(200)
);
-- COPY staging.stg_vendor_prices
-- FROM '/absolute/path/to/data/raw/2017PurchasePricesDec.csv'
-- CSV HEADER ENCODING 'UTF8';
