-- =============================================================
-- 02_create_dimensions.sql
-- Creates dimension tables for the Inventory star schema
-- =============================================================

CREATE SCHEMA IF NOT EXISTS warehouse;

-- ------------------------------------------------------------
-- dim_date
-- ------------------------------------------------------------
DROP TABLE IF EXISTS warehouse.dim_date CASCADE;
CREATE TABLE warehouse.dim_date (
    date_key        INT            PRIMARY KEY,   -- YYYYMMDD
    full_date       DATE           NOT NULL UNIQUE,
    year            SMALLINT       NOT NULL,
    quarter         SMALLINT       NOT NULL,
    month           SMALLINT       NOT NULL,
    month_name      VARCHAR(10)    NOT NULL,
    week            SMALLINT       NOT NULL,      -- ISO week
    day_of_week     SMALLINT       NOT NULL,      -- 1=Mon … 7=Sun
    day_name        VARCHAR(10)    NOT NULL,
    is_weekend      BOOLEAN        NOT NULL
);

-- Populate dim_date for 2015-01-01 → 2017-12-31
INSERT INTO warehouse.dim_date
SELECT
    TO_CHAR(d, 'YYYYMMDD')::INT                  AS date_key,
    d::DATE                                       AS full_date,
    EXTRACT(YEAR    FROM d)::SMALLINT             AS year,
    EXTRACT(QUARTER FROM d)::SMALLINT             AS quarter,
    EXTRACT(MONTH   FROM d)::SMALLINT             AS month,
    TO_CHAR(d, 'Mon')                             AS month_name,
    EXTRACT(ISOYEAR FROM d)::SMALLINT             AS week,
    EXTRACT(ISODOW  FROM d)::SMALLINT             AS day_of_week,
    TO_CHAR(d, 'Dy')                              AS day_name,
    EXTRACT(ISODOW  FROM d) IN (6,7)              AS is_weekend
FROM generate_series('2015-01-01'::DATE, '2017-12-31'::DATE, '1 day') AS d;

-- ------------------------------------------------------------
-- dim_product
-- ------------------------------------------------------------
DROP TABLE IF EXISTS warehouse.dim_product CASCADE;
CREATE TABLE warehouse.dim_product (
    product_key         SERIAL         PRIMARY KEY,
    brand_id            INT            NOT NULL,
    description         VARCHAR(200),
    size                VARCHAR(30),
    volume_ml           INT,           -- numeric mL extracted from volume/size
    classification      INT,
    classification_name VARCHAR(30),   -- 'Spirits','Wine','Beer','Other'
    retail_price        NUMERIC(10,2),
    purchase_price      NUMERIC(10,2),
    gross_margin_pct    NUMERIC(6,4),  -- (retail - cost) / retail
    vendor_number       INT,
    vendor_name         VARCHAR(100)
);

CREATE UNIQUE INDEX uix_dim_product_brand ON warehouse.dim_product(brand_id);

-- ------------------------------------------------------------
-- dim_store
-- ------------------------------------------------------------
DROP TABLE IF EXISTS warehouse.dim_store CASCADE;
CREATE TABLE warehouse.dim_store (
    store_key   SERIAL      PRIMARY KEY,
    store_id    INT         NOT NULL UNIQUE,
    city        VARCHAR(80)
);

-- ------------------------------------------------------------
-- dim_vendor
-- ------------------------------------------------------------
DROP TABLE IF EXISTS warehouse.dim_vendor CASCADE;
CREATE TABLE warehouse.dim_vendor (
    vendor_key          SERIAL      PRIMARY KEY,
    vendor_number       INT         NOT NULL UNIQUE,
    vendor_name         VARCHAR(100),
    avg_lead_time_days  NUMERIC(6,2)  -- populated after fact_purchases load
);
