BEGIN; 

-- =============================================
-- STEP 1: 建立 Schema
-- =============================================
CREATE SCHEMA IF NOT EXISTS stg_raw; -- Staging 層 (TEXT)
CREATE SCHEMA IF NOT EXISTS stg;     -- Staging 層
CREATE SCHEMA IF NOT EXISTS ods;     -- ODS 清洗層（後續用）
CREATE SCHEMA IF NOT EXISTS dwh;     -- DWH 星型模型層（後續用）

-- =============================================
-- STEP 2: 建立 stg_raw 表
-- =============================================
-- 2.1 sales_raw
DROP TABLE IF EXISTS stg_raw.sales_raw;

CREATE TABLE stg_raw.sales_raw (
    inventory_id    TEXT,
    store           TEXT,
    brand           TEXT,
    description     TEXT,
    size            TEXT,
    sales_quantity  TEXT,
    sales_dollars   TEXT,
    sales_price     TEXT,
    sales_date      TEXT,
    volume          TEXT,
    classification  TEXT,
    excise_tax      TEXT,
    vendor_no       TEXT,
    vendor_name     TEXT
);

-- 2.2 purchases_raw
DROP TABLE IF EXISTS stg_raw.purchases_raw;

CREATE TABLE stg_raw.purchases_raw (
    inventory_id    TEXT,
    store           TEXT,
    brand           TEXT,
    description     TEXT,
    size            TEXT,
    vendor_number   TEXT,
    vendor_name     TEXT,
    po_number       TEXT,
    po_date         TEXT,
    receiving_date  TEXT,
    invoice_date    TEXT,
    pay_date        TEXT,
    purchase_price  TEXT,
    quantity        TEXT,
    dollars         TEXT,
    classification  TEXT
);

-- 2.3 invoice_purchases_raw
DROP TABLE IF EXISTS stg_raw.invoice_purchases_raw;

CREATE TABLE stg_raw.invoice_purchases_raw (
    vendor_number   TEXT,
    vendor_name     TEXT,
    invoice_date    TEXT,
    po_number       TEXT,
    po_date         TEXT,
    pay_date        TEXT,
    quantity        TEXT,
    dollars         TEXT,
    freight         TEXT,
    approval        TEXT
);
-- 2.4 beg_inv_raw
DROP TABLE IF EXISTS stg_raw.beg_inv_raw;

CREATE TABLE stg_raw.beg_inv_raw (
    inventory_id    TEXT,
    store           TEXT,
    city            TEXT,
    brand           TEXT,
    description     TEXT,
    size            TEXT,
    on_hand         TEXT,
    price           TEXT,
    start_date      TEXT
);

-- 2.5 end_inv_raw
DROP TABLE IF EXISTS stg_raw.end_inv_raw;

CREATE TABLE stg_raw.end_inv_raw (
    inventory_id    TEXT,
    store           TEXT,
    city            TEXT,
    brand           TEXT,
    description     TEXT,
    size            TEXT,
    on_hand         TEXT,
    price           TEXT,
    end_date        TEXT
);

-- 2.6 purchase_prices_raw
DROP TABLE IF EXISTS stg_raw.purchase_prices_raw;

CREATE TABLE stg_raw.purchase_prices_raw (
    brand           TEXT,
    description     TEXT,
    price           TEXT,
    size            TEXT,
    volume          TEXT,
    classification  TEXT,
    purchase_price  TEXT,
    vendor_number   TEXT,
    vendor_name     TEXT
);


-- =============================================
-- STEP 3: COPY 匯入 raw 表
-- =============================================

COPY stg_raw.sales_raw
FROM 'C:/Program Files/PostgreSQL/18/data/Bibitor/SalesFINAL12312016.csv'
WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');

COPY stg_raw.purchases_raw
FROM 'C:/Program Files/PostgreSQL/18/data/Bibitor/PurchasesFINAL12312016.csv'
WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');

COPY stg_raw.invoice_purchases_raw
FROM 'C:/Program Files/PostgreSQL/18/data/Bibitor/InvoicePurchases12312016.csv'
WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');

COPY stg_raw.beg_inv_raw
FROM 'C:/Program Files/PostgreSQL/18/data/Bibitor/BegInvFINAL12312016.csv'
WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');

COPY stg_raw.end_inv_raw
FROM 'C:/Program Files/PostgreSQL/18/data/Bibitor/EndInvFINAL12312016.csv'
WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');

COPY stg_raw.purchase_prices_raw
FROM 'C:/Program Files/PostgreSQL/18/data/Bibitor/2017PurchasePricesDec.csv'
WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');


-- =============================================
-- STEP 4: 看 raw 品質
-- =============================================
-- 4.1 檢查 raw 日期格式分佈
SELECT
    CASE
        WHEN TRIM(sales_date) ~ '^\d{4}-\d{2}-\d{2}$' THEN 'ISO_YYYY_MM_DD'
        WHEN TRIM(sales_date) ~ '^\d{1,2}/\d{1,2}/\d{4}$' THEN 'US_MM_DD_YYYY'
        WHEN TRIM(sales_date) IS NULL OR TRIM(sales_date) = '' THEN 'BLANK'
        ELSE 'INVALID_FORMAT'
    END AS sales_date_format,
    COUNT(*) AS row_count
FROM stg_raw.sales_raw
GROUP BY 1
ORDER BY row_count DESC;

-- 4.2 找出不能轉成數字的 sales 欄位
SELECT *
FROM stg_raw.sales_raw
WHERE
    (TRIM(store) <> ''          AND TRIM(store) !~ '^-?\d+$')
 OR (TRIM(brand) <> ''          AND TRIM(brand) !~ '^-?\d+$')
 OR (TRIM(sales_quantity) <> '' AND TRIM(sales_quantity) !~ '^-?\d+$')
 OR (TRIM(sales_dollars) <> ''  AND TRIM(sales_dollars) !~ '^-?\d+(\.\d+)?$')
 OR (TRIM(sales_price) <> ''    AND TRIM(sales_price) !~ '^-?\d+(\.\d+)?$')
 OR (TRIM(volume) <> ''         AND TRIM(volume) !~ '^-?\d+(\.\d+)?$')
 OR (TRIM(classification) <> '' AND TRIM(classification) !~ '^-?\d+$')
 OR (TRIM(excise_tax) <> ''     AND TRIM(excise_tax) !~ '^-?\d+(\.\d+)?$')
 OR (TRIM(vendor_no) <> ''      AND TRIM(vendor_no) !~ '^-?\d+$')
LIMIT 100;

-- 4.3 找出 raw sales 壞日期
SELECT *
FROM stg_raw.sales_raw
WHERE NOT (
    TRIM(sales_date) ~ '^\d{4}-\d{2}-\d{2}$'
    OR TRIM(sales_date) ~ '^\d{1,2}/\d{1,2}/\d{4}$'
    OR TRIM(sales_date) = ''
    OR sales_date IS NULL
)
LIMIT 100;

-- 4.4 找出 purchases 壞數字 / 壞日期
SELECT *
FROM stg_raw.purchases_raw
WHERE
    NOT (
        TRIM(po_date) ~ '^\d{4}-\d{2}-\d{2}$'
        OR TRIM(po_date) ~ '^\d{1,2}/\d{1,2}/\d{4}$'
        OR TRIM(po_date) = ''
        OR po_date IS NULL
    )
 OR NOT (
        TRIM(receiving_date) ~ '^\d{4}-\d{2}-\d{2}$'
        OR TRIM(receiving_date) ~ '^\d{1,2}/\d{1,2}/\d{4}$'
        OR TRIM(receiving_date) = ''
        OR receiving_date IS NULL
    )
 OR (TRIM(quantity) <> '' AND TRIM(quantity) !~ '^-?\d+$')
 OR (TRIM(dollars) <> '' AND TRIM(dollars) !~ '^-?\d+(\.\d+)?$')
 OR (TRIM(purchase_price) <> '' AND TRIM(purchase_price) !~ '^-?\d+(\.\d+)?$')
LIMIT 100;


-- =============================================
-- STEP 5: 建立 stg 表
-- =============================================
-- 5.1 sales
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
    sales_date      DATE,
    volume          NUMERIC(10,2),
    classification  INTEGER,
    excise_tax      NUMERIC(10,2),
    vendor_no       INTEGER,
    vendor_name     TEXT
);

-- 5.2 purchases
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

-- 5.3 invoice_purchases
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
    freight         NUMERIC(10,2),
    approval        TEXT
);

-- 5.4 beg_inv / end_inv / purchase_prices
DROP TABLE IF EXISTS stg.beg_inv;
CREATE TABLE stg.beg_inv (
    inventory_id    TEXT,
    store           INTEGER,
    city            TEXT,
    brand           INTEGER,
    description     TEXT,
    size            TEXT,
    on_hand         NUMERIC(12,2),
    price           NUMERIC(10,2),
    start_date      DATE
);

DROP TABLE IF EXISTS stg.end_inv;
CREATE TABLE stg.end_inv (
    inventory_id    TEXT,
    store           INTEGER,
    city            TEXT,
    brand           INTEGER,
    description     TEXT,
    size            TEXT,
    on_hand         NUMERIC(12,2),
    price           NUMERIC(10,2),
    end_date        DATE
);

DROP TABLE IF EXISTS stg.purchase_prices;
CREATE TABLE stg.purchase_prices (
    brand           INTEGER,
    description     TEXT,
    price           NUMERIC(10,2),
    size            TEXT,
    volume          NUMERIC(10,2),
    classification  INTEGER,
    purchase_price  NUMERIC(10,2),
    vendor_number   INTEGER,
    vendor_name     TEXT
);

-- =============================================
-- STEP 6: 日期清洗與型別轉換 SQL
-- 核心原則：
-- ISO 日期 YYYY-MM-DD → 直接 ::date。
-- 美式日期 M/D/YYYY 或 MM/DD/YYYY → to_date(..., 'MM/DD/YYYY')。
-- 非法值 → 轉成 NULL，先不讓整批失敗。
-- =============================================
-- 6.1 sales 轉入 stg
INSERT INTO stg.sales (
    inventory_id, store, brand, description, size,
    sales_quantity, sales_dollars, sales_price, sales_date,
    volume, classification, excise_tax, vendor_no, vendor_name
)
SELECT
    NULLIF(TRIM(inventory_id), ''),
    NULLIF(TRIM(store), '')::INTEGER,
    NULLIF(TRIM(brand), '')::INTEGER,
    NULLIF(TRIM(description), ''),
    NULLIF(TRIM(size), ''),
    NULLIF(TRIM(sales_quantity), '')::INTEGER,
    NULLIF(TRIM(sales_dollars), '')::NUMERIC(12,2),
    NULLIF(TRIM(sales_price), '')::NUMERIC(10,2),
    CASE
        WHEN TRIM(sales_date) ~ '^\d{4}-\d{2}-\d{2}$'
            THEN TRIM(sales_date)::DATE
        WHEN TRIM(sales_date) ~ '^\d{1,2}/\d{1,2}/\d{4}$'
            THEN TO_DATE(TRIM(sales_date), 'MM/DD/YYYY')
        ELSE NULL
    END,
    CASE
	    WHEN volume IS NULL OR TRIM(volume) = '' THEN NULL
	    WHEN LOWER(TRIM(volume)) = 'unknown'    THEN NULL
	    ELSE TRIM(volume)::NUMERIC(10,2)
	END AS volume,
    NULLIF(TRIM(classification), '')::INTEGER,
    NULLIF(TRIM(excise_tax), '')::NUMERIC(10,2),
    NULLIF(TRIM(vendor_no), '')::INTEGER,
    NULLIF(TRIM(vendor_name), '')
FROM stg_raw.sales_raw;

-- 6.2 purchases 轉入 stg
INSERT INTO stg.purchases (
    inventory_id, store, brand, description, size,
    vendor_number, vendor_name, po_number, po_date, receiving_date,
    invoice_date, pay_date, purchase_price, quantity, dollars, classification
)
SELECT
    NULLIF(TRIM(inventory_id), ''),
    NULLIF(TRIM(store), '')::INTEGER,
    NULLIF(TRIM(brand), '')::INTEGER,
    NULLIF(TRIM(description), ''),
    NULLIF(TRIM(size), ''),
    NULLIF(TRIM(vendor_number), '')::INTEGER,
    NULLIF(TRIM(vendor_name), ''),
    NULLIF(TRIM(po_number), '')::INTEGER,
    CASE
        WHEN TRIM(po_date) ~ '^\d{4}-\d{2}-\d{2}$' THEN TRIM(po_date)::DATE
        WHEN TRIM(po_date) ~ '^\d{1,2}/\d{1,2}/\d{4}$' THEN TO_DATE(TRIM(po_date), 'MM/DD/YYYY')
        ELSE NULL
    END,
    CASE
        WHEN TRIM(receiving_date) ~ '^\d{4}-\d{2}-\d{2}$' THEN TRIM(receiving_date)::DATE
        WHEN TRIM(receiving_date) ~ '^\d{1,2}/\d{1,2}/\d{4}$' THEN TO_DATE(TRIM(receiving_date), 'MM/DD/YYYY')
        ELSE NULL
    END,
    CASE
        WHEN TRIM(invoice_date) ~ '^\d{4}-\d{2}-\d{2}$' THEN TRIM(invoice_date)::DATE
        WHEN TRIM(invoice_date) ~ '^\d{1,2}/\d{1,2}/\d{4}$' THEN TO_DATE(TRIM(invoice_date), 'MM/DD/YYYY')
        ELSE NULL
    END,
    CASE
        WHEN TRIM(pay_date) ~ '^\d{4}-\d{2}-\d{2}$' THEN TRIM(pay_date)::DATE
        WHEN TRIM(pay_date) ~ '^\d{1,2}/\d{1,2}/\d{4}$' THEN TO_DATE(TRIM(pay_date), 'MM/DD/YYYY')
        ELSE NULL
    END,
    NULLIF(TRIM(purchase_price), '')::NUMERIC(10,2),
    NULLIF(TRIM(quantity), '')::INTEGER,
    NULLIF(TRIM(dollars), '')::NUMERIC(12,2),
    NULLIF(TRIM(classification), '')::INTEGER
FROM stg_raw.purchases_raw;

-- 6.3 invoice_purchases 轉入 stg
INSERT INTO stg.invoice_purchases (
    vendor_number, vendor_name, invoice_date, po_number, po_date,
    pay_date, quantity, dollars, freight, approval
)
SELECT
    NULLIF(TRIM(vendor_number), '')::INTEGER,
    NULLIF(TRIM(vendor_name), ''),
    CASE
        WHEN TRIM(invoice_date) ~ '^\d{4}-\d{2}-\d{2}$' THEN TRIM(invoice_date)::DATE
        WHEN TRIM(invoice_date) ~ '^\d{1,2}/\d{1,2}/\d{4}$' THEN TO_DATE(TRIM(invoice_date), 'MM/DD/YYYY')
        ELSE NULL
    END,
    NULLIF(TRIM(po_number), '')::INTEGER,
    CASE
        WHEN TRIM(po_date) ~ '^\d{4}-\d{2}-\d{2}$' THEN TRIM(po_date)::DATE
        WHEN TRIM(po_date) ~ '^\d{1,2}/\d{1,2}/\d{4}$' THEN TO_DATE(TRIM(po_date), 'MM/DD/YYYY')
        ELSE NULL
    END,
    CASE
        WHEN TRIM(pay_date) ~ '^\d{4}-\d{2}-\d{2}$' THEN TRIM(pay_date)::DATE
        WHEN TRIM(pay_date) ~ '^\d{1,2}/\d{1,2}/\d{4}$' THEN TO_DATE(TRIM(pay_date), 'MM/DD/YYYY')
        ELSE NULL
    END,
    NULLIF(TRIM(quantity), '')::INTEGER,
    NULLIF(TRIM(dollars), '')::NUMERIC(12,2),
    NULLIF(TRIM(freight), '')::NUMERIC(10,2),
    NULLIF(TRIM(approval), '')
FROM stg_raw.invoice_purchases_raw;

-- 6.4 beg_inv / end_inv / purchase_prices 轉入 stg
INSERT INTO stg.beg_inv (
    inventory_id, store, city, brand, description, size, on_hand, price, start_date
)
SELECT
    NULLIF(TRIM(inventory_id), ''),
    NULLIF(TRIM(store), '')::INTEGER,
    NULLIF(TRIM(city), ''),
    NULLIF(TRIM(brand), '')::INTEGER,
    NULLIF(TRIM(description), ''),
    NULLIF(TRIM(size), ''),
    NULLIF(TRIM(on_hand), '')::NUMERIC(12,2),
    NULLIF(TRIM(price), '')::NUMERIC(10,2),
    CASE
        WHEN TRIM(start_date) ~ '^\d{4}-\d{2}-\d{2}$' THEN TRIM(start_date)::DATE
        WHEN TRIM(start_date) ~ '^\d{1,2}/\d{1,2}/\d{4}$' THEN TO_DATE(TRIM(start_date), 'MM/DD/YYYY')
        ELSE NULL
    END
FROM stg_raw.beg_inv_raw;

INSERT INTO stg.end_inv (
    inventory_id, store, city, brand, description, size, on_hand, price, end_date
)
SELECT
    NULLIF(TRIM(inventory_id), ''),
    NULLIF(TRIM(store), '')::INTEGER,
    NULLIF(TRIM(city), ''),
    NULLIF(TRIM(brand), '')::INTEGER,
    NULLIF(TRIM(description), ''),
    NULLIF(TRIM(size), ''),
    NULLIF(TRIM(on_hand), '')::NUMERIC(12,2),
    NULLIF(TRIM(price), '')::NUMERIC(10,2),
    CASE
        WHEN TRIM(end_date) ~ '^\d{4}-\d{2}-\d{2}$' THEN TRIM(end_date)::DATE
        WHEN TRIM(end_date) ~ '^\d{1,2}/\d{1,2}/\d{4}$' THEN TO_DATE(TRIM(end_date), 'MM/DD/YYYY')
        ELSE NULL
    END
FROM stg_raw.end_inv_raw;

INSERT INTO stg.purchase_prices (
    brand, description, price, size, volume, classification, purchase_price, vendor_number, vendor_name
)
SELECT
    NULLIF(TRIM(brand), '')::INTEGER,
    NULLIF(TRIM(description), ''),
    NULLIF(TRIM(price), '')::NUMERIC(10,2),
    NULLIF(TRIM(size), ''),
    CASE
	    WHEN volume IS NULL OR TRIM(volume) = '' THEN NULL
	    WHEN LOWER(TRIM(volume)) = 'unknown'    THEN NULL
	    ELSE TRIM(volume)::NUMERIC(10,2)
	END AS volume,
    NULLIF(TRIM(classification), '')::INTEGER,
    NULLIF(TRIM(purchase_price), '')::NUMERIC(10,2),
    NULLIF(TRIM(vendor_number), '')::INTEGER,
    NULLIF(TRIM(vendor_name), '')
FROM stg_raw.purchase_prices_raw;

-- =============================================
-- STEP 7: 驗證stg
-- =============================================
-- 7.1 檢查正式表載入後的 NULL / 轉型失敗殘留
SELECT
    COUNT(*) AS total_rows,
    COUNT(*) FILTER (WHERE sales_date IS NULL)       AS null_sales_date,
    COUNT(*) FILTER (WHERE store IS NULL)            AS null_store,
    COUNT(*) FILTER (WHERE brand IS NULL)            AS null_brand,
    COUNT(*) FILTER (WHERE sales_quantity IS NULL)   AS null_sales_quantity,
    COUNT(*) FILTER (WHERE sales_dollars IS NULL)    AS null_sales_dollars,
    COUNT(*) FILTER (WHERE volume IS NULL)           AS null_volume
FROM stg.sales;

-- 7.2 檢查日期範圍是否合理
SELECT
    MIN(sales_date) AS min_sales_date,
    MAX(sales_date) AS max_sales_date,
    COUNT(DISTINCT DATE_TRUNC('month', sales_date)) AS distinct_months
FROM stg.sales;

-- 7.3 檢查邏輯錯誤日期
SELECT
    COUNT(*) FILTER (WHERE receiving_date < po_date)      AS recv_before_po,
    COUNT(*) FILTER (WHERE invoice_date < po_date)        AS inv_before_po,
    COUNT(*) FILTER (WHERE pay_date < invoice_date)       AS pay_before_inv
FROM stg.purchases;




COMMIT;