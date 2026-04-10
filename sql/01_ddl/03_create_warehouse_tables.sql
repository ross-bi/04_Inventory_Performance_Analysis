-- ============================================================
-- FILE: sql/01_ddl/03_create_warehouse_tables.sql
-- PURPOSE: Layer 3 - Star Schema DDL (Dim + Fact)
-- NOTE: Tables are created via CTAS in 02_elt/03_load_warehouse.sql
--       This file documents the logical schema with explicit types.
-- ============================================================

CREATE SCHEMA IF NOT EXISTS warehouse;

-- ---------------------------------------------------------
-- dim_date
-- ---------------------------------------------------------
DROP TABLE IF EXISTS warehouse.dim_date CASCADE;
CREATE TABLE warehouse.dim_date (
    date_key        DATE        PRIMARY KEY,
    year            SMALLINT    NOT NULL,
    quarter         SMALLINT    NOT NULL,
    month           SMALLINT    NOT NULL,
    month_name      VARCHAR(20) NOT NULL,
    week            SMALLINT    NOT NULL,
    day_of_week     SMALLINT    NOT NULL,    -- 0=Sunday, 6=Saturday
    is_weekend      BOOLEAN     NOT NULL
);

-- ---------------------------------------------------------
-- dim_product
-- ---------------------------------------------------------
DROP TABLE IF EXISTS warehouse.dim_product CASCADE;
CREATE TABLE warehouse.dim_product (
    brand_id        INTEGER     PRIMARY KEY,
    description     TEXT        NOT NULL,
    size            TEXT,
    volume_ml       INTEGER,
    class_id        SMALLINT,
    class_name      VARCHAR(20)
);

-- ---------------------------------------------------------
-- dim_store
-- ---------------------------------------------------------
DROP TABLE IF EXISTS warehouse.dim_store CASCADE;
CREATE TABLE warehouse.dim_store (
    store_id        INTEGER     PRIMARY KEY,
    store_name      VARCHAR(100)
);

-- ---------------------------------------------------------
-- dim_vendor
-- ---------------------------------------------------------
DROP TABLE IF EXISTS warehouse.dim_vendor CASCADE;
CREATE TABLE warehouse.dim_vendor (
    vendor_id       INTEGER     PRIMARY KEY,
    vendor_name     VARCHAR(200)
);

-- ---------------------------------------------------------
-- fact_inventory
-- Grain: 1 row = 1 SKU x Store x Year x Month
-- ---------------------------------------------------------
DROP TABLE IF EXISTS warehouse.fact_inventory CASCADE;
CREATE TABLE warehouse.fact_inventory (
    fact_id                 SERIAL          PRIMARY KEY,
    brand_id                INTEGER         NOT NULL REFERENCES warehouse.dim_product(brand_id),
    store_id                INTEGER         NOT NULL REFERENCES warehouse.dim_store(store_id),
    sale_year               SMALLINT        NOT NULL,
    sale_month              SMALLINT        NOT NULL,
    -- Sales measures
    total_sales_qty         INTEGER,
    total_sales_dollars     NUMERIC(14,2),
    total_excise_tax        NUMERIC(12,2),
    selling_days            SMALLINT,
    -- Purchase measures
    total_purchase_qty      INTEGER,
    total_purchase_dollars  NUMERIC(14,2),
    -- Inventory measures
    beg_inventory           INTEGER,
    end_inventory           INTEGER,
    avg_inventory           NUMERIC(10,2),
    -- KPI columns
    inventory_turnover      NUMERIC(10,4),
    dsi                     NUMERIC(10,1),
    -- Metadata
    loaded_at               TIMESTAMP       NOT NULL DEFAULT NOW()
);

-- Indexes for Power BI performance
CREATE INDEX idx_fact_inv_brand  ON warehouse.fact_inventory(brand_id);
CREATE INDEX idx_fact_inv_store  ON warehouse.fact_inventory(store_id);
CREATE INDEX idx_fact_inv_period ON warehouse.fact_inventory(sale_year, sale_month);
