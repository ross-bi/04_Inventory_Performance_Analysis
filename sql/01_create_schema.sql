-- =============================================================================
-- 04 Inventory Performance Analysis
-- Script 01: Create Schema - Dimension & Fact Tables
-- Database: PostgreSQL 16
-- Schema: Kimball Star Schema
-- =============================================================================

DROP SCHEMA IF EXISTS inventory CASCADE;
CREATE SCHEMA inventory;
SET search_path = inventory;


-- =============================================================================
-- DIMENSION TABLES
-- =============================================================================

CREATE TABLE dim_date (
    date_key        INT             PRIMARY KEY,   -- YYYYMMDD integer key
    full_date       DATE            NOT NULL,
    year            SMALLINT        NOT NULL,
    quarter         SMALLINT        NOT NULL,
    month           SMALLINT        NOT NULL,
    month_name      VARCHAR(9)      NOT NULL,
    week_of_year    SMALLINT        NOT NULL,
    day_of_week     SMALLINT        NOT NULL,      -- 1=Monday ... 7=Sunday
    day_name        VARCHAR(9)      NOT NULL,
    is_weekend      BOOLEAN         NOT NULL DEFAULT FALSE
);


CREATE TABLE dim_product (
    product_key     SERIAL          PRIMARY KEY,
    brand           VARCHAR(100)    NOT NULL,
    description     VARCHAR(255)    NOT NULL,
    size            VARCHAR(50),
    classification  VARCHAR(50),                  -- WINE / SPIRITS
    volume_ml       NUMERIC(8,2),
    UNIQUE (brand, description, size)
);


CREATE TABLE dim_store (
    store_key       SERIAL          PRIMARY KEY,
    store_id        INT             NOT NULL UNIQUE,
    city            VARCHAR(100),
    state           CHAR(2)         DEFAULT 'LN'
);


CREATE TABLE dim_vendor (
    vendor_key      SERIAL          PRIMARY KEY,
    vendor_number   INT             NOT NULL UNIQUE,
    vendor_name     VARCHAR(200)    NOT NULL
);


-- =============================================================================
-- FACT TABLES
-- =============================================================================

-- Grain: 1 row per store x product x period_type (BEG / END)
CREATE TABLE fact_inventory_snapshot (
    snapshot_id     BIGSERIAL       PRIMARY KEY,
    date_key        INT             NOT NULL REFERENCES dim_date(date_key),
    store_key       INT             NOT NULL REFERENCES dim_store(store_key),
    product_key     INT             NOT NULL REFERENCES dim_product(product_key),
    period_type     CHAR(3)         NOT NULL CHECK (period_type IN ('BEG','END')),
    on_hand_qty     NUMERIC(12,2)   NOT NULL DEFAULT 0,
    unit_price      NUMERIC(10,2),
    inventory_value NUMERIC(14,2)                -- on_hand_qty x unit_price
);

CREATE INDEX idx_inv_snapshot_store_product
    ON fact_inventory_snapshot (store_key, product_key, period_type);


-- Grain: 1 row per store x product x sales date
CREATE TABLE fact_sales (
    sale_id         BIGSERIAL       PRIMARY KEY,
    date_key        INT             NOT NULL REFERENCES dim_date(date_key),
    store_key       INT             NOT NULL REFERENCES dim_store(store_key),
    product_key     INT             NOT NULL REFERENCES dim_product(product_key),
    vendor_key      INT             REFERENCES dim_vendor(vendor_key),
    sales_qty       NUMERIC(12,2)   NOT NULL DEFAULT 0,
    sales_dollars   NUMERIC(14,2)   NOT NULL DEFAULT 0,
    sales_price     NUMERIC(10,2),
    excise_tax      NUMERIC(10,2)
);

CREATE INDEX idx_sales_date        ON fact_sales (date_key);
CREATE INDEX idx_sales_store       ON fact_sales (store_key);
CREATE INDEX idx_sales_product     ON fact_sales (product_key);
CREATE INDEX idx_sales_store_prod  ON fact_sales (store_key, product_key);


-- Grain: 1 row per purchase transaction (PO line item)
CREATE TABLE fact_purchases (
    purchase_id         BIGSERIAL       PRIMARY KEY,
    receiving_date_key  INT             NOT NULL REFERENCES dim_date(date_key),
    approval_date_key   INT             REFERENCES dim_date(date_key),
    store_key           INT             NOT NULL REFERENCES dim_store(store_key),
    product_key         INT             NOT NULL REFERENCES dim_product(product_key),
    vendor_key          INT             NOT NULL REFERENCES dim_vendor(vendor_key),
    purchase_qty        NUMERIC(12,2)   NOT NULL DEFAULT 0,
    purchase_dollars    NUMERIC(14,2)   NOT NULL DEFAULT 0,
    purchase_price      NUMERIC(10,2),
    freight_cost        NUMERIC(10,2),
    lead_time_days      INT                      -- receiving_date - approval_date
);

CREATE INDEX idx_pur_receiving_date  ON fact_purchases (receiving_date_key);
CREATE INDEX idx_pur_store_product   ON fact_purchases (store_key, product_key);
CREATE INDEX idx_pur_vendor          ON fact_purchases (vendor_key);
