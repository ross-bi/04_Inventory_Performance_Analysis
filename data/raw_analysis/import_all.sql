BEGIN; 

-- =============================================
-- STEP 1: 建立 Schema
-- =============================================
CREATE SCHEMA IF NOT EXISTS stg;    -- Staging 層
CREATE SCHEMA IF NOT EXISTS ods;    -- ODS 清洗層（後續用）
CREATE SCHEMA IF NOT EXISTS dwh;    -- DWH 星型模型層（後續用）

-- =============================================
-- STEP 2: 建立 Staging 表（snake_case，1:1 對應 CSV）
-- =============================================

-- 2a. 期初庫存
DROP TABLE IF EXISTS stg.beg_inv;
CREATE TABLE stg.beg_inv (
    inventory_id   TEXT,
    store          INTEGER,
    city           TEXT,
    brand          INTEGER,
    description    TEXT,
    size           TEXT,
    on_hand        INTEGER,
    price          NUMERIC(10,2),
    start_date     DATE
);

-- 2b. 期末庫存
DROP TABLE IF EXISTS stg.end_inv;
CREATE TABLE stg.end_inv (
    inventory_id   TEXT,
    store          INTEGER,
    city           TEXT,
    brand          INTEGER,
    description    TEXT,
    size           TEXT,
    on_hand        INTEGER,
    price          NUMERIC(10,2),
    end_date       DATE
);

-- 2c. 採購明細
DROP TABLE IF EXISTS stg.purchases;
CREATE TABLE stg.purchases (
    inventory_id    TEXT,
    store           INTEGER,
    brand           INTEGER,
    description     TEXT,
    size            TEXT,
    vendor_number   INTEGER,
    vendor_name     TEXT,
    po_number       INTEGER,
    po_date         DATE,
    receiving_date  DATE,
    invoice_date    DATE,
    pay_date        DATE,
    purchase_price  NUMERIC(10,2),
    quantity        INTEGER,
    dollars         NUMERIC(12,2),
    classification  INTEGER
);

-- 2d. 發票採購（Vendor 彙總）
DROP TABLE IF EXISTS stg.invoice_purchases;
CREATE TABLE stg.invoice_purchases (
    vendor_number   INTEGER,
    vendor_name     TEXT,
    invoice_date    DATE,
    po_number       INTEGER,
    po_date         DATE,
    pay_date        DATE,
    quantity        INTEGER,
    dollars         NUMERIC(12,2),
    freight         NUMERIC(12,2),
    approval        TEXT
);

-- 2e. 銷售明細
DROP TABLE IF EXISTS stg.sales;
CREATE TABLE stg.sales (
    inventory_id    TEXT,
    store           INTEGER,
    brand           INTEGER,
    description     TEXT,
    size            TEXT,
    sales_quantity  INTEGER,
    sales_dollars   NUMERIC(12,2),
    sales_price     NUMERIC(10,2),
    sales_date      TEXT,  -- 注意：原始資料中日期格式不一致，先用 TEXT 匯入，後續清洗轉 DATE
    volume          INTEGER,
    classification  INTEGER,
    excise_tax      NUMERIC(10,2),
    vendor_no       INTEGER,
    vendor_name     TEXT
);

-- 2f. 產品主檔＋採購定價
DROP TABLE IF EXISTS stg.purchase_prices;
CREATE TABLE stg.purchase_prices (
    brand            INTEGER,
    description      TEXT,
    price            NUMERIC(10,2),
    size             TEXT,
    volume           TEXT,
    classification   INTEGER,
    purchase_price   NUMERIC(10,2),
    vendor_number    INTEGER,
    vendor_name      TEXT
);

-- =============================================
-- STEP 3: COPY 匯入（路徑改為你的實際路徑）
-- =============================================
COPY stg.beg_inv          
FROM 'C:/Program Files/PostgreSQL/18/data/Bibitor/BegInvFINAL12312016.csv'       
WITH (FORMAT csv, HEADER true, DELIMITER ',', QUOTE '"', NULL '');

COPY stg.end_inv           
FROM 'C:/Program Files/PostgreSQL/18/data/Bibitor/EndInvFINAL12312016.csv'       
WITH (FORMAT csv, HEADER true, DELIMITER ',', QUOTE '"', NULL '');

COPY stg.purchases         
FROM 'C:/Program Files/PostgreSQL/18/data/Bibitor/PurchasesFINAL12312016.csv'    
WITH (FORMAT csv, HEADER true, DELIMITER ',', QUOTE '"', NULL '');

COPY stg.invoice_purchases 
FROM 'C:/Program Files/PostgreSQL/18/data/Bibitor/InvoicePurchases12312016.csv'  
WITH (FORMAT csv, HEADER true, DELIMITER ',', QUOTE '"', NULL '');

COPY stg.sales             
FROM 'C:/Program Files/PostgreSQL/18/data/Bibitor/SalesFINAL12312016.csv'        
WITH (FORMAT csv, HEADER true, DELIMITER ',', QUOTE '"', NULL '');

COPY stg.purchase_prices   
FROM 'C:/Program Files/PostgreSQL/18/data/Bibitor/2017PurchasePricesDec.csv'     
WITH (FORMAT csv, HEADER true, DELIMITER ',', QUOTE '"', NULL '');


-- 轉換 SalesDate 格式
ALTER TABLE stg.sales ADD COLUMN "sales_date_dt" DATE;
UPDATE stg.sales SET "sales_date_dt" = TO_DATE("sales_date", 'MM/DD/YYYY');
ALTER TABLE stg.sales DROP COLUMN "sales_date";
ALTER TABLE stg.sales RENAME COLUMN "sales_date_dt" TO "sales_date";

COMMIT;