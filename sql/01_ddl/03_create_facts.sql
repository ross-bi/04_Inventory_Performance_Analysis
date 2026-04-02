-- =============================================================
-- 03_create_facts.sql
-- Creates fact tables for the Inventory star schema
-- =============================================================

-- ------------------------------------------------------------
-- fact_sales
-- ------------------------------------------------------------
DROP TABLE IF EXISTS warehouse.fact_sales CASCADE;
CREATE TABLE warehouse.fact_sales (
    sale_key        BIGSERIAL      PRIMARY KEY,
    date_key        INT            NOT NULL REFERENCES warehouse.dim_date(date_key),
    product_key     INT            NOT NULL REFERENCES warehouse.dim_product(product_key),
    store_key       INT            NOT NULL REFERENCES warehouse.dim_store(store_key),
    vendor_key      INT            REFERENCES warehouse.dim_vendor(vendor_key),
    sales_quantity  INT            NOT NULL DEFAULT 0,
    sales_dollars   NUMERIC(12,2)  NOT NULL DEFAULT 0,
    sales_price     NUMERIC(10,2),
    excise_tax      NUMERIC(8,2),
    cogs            NUMERIC(12,2), -- purchase_price * sales_quantity
    gross_profit    NUMERIC(12,2)  -- sales_dollars - cogs
);

CREATE INDEX ix_fact_sales_date    ON warehouse.fact_sales(date_key);
CREATE INDEX ix_fact_sales_product ON warehouse.fact_sales(product_key);
CREATE INDEX ix_fact_sales_store   ON warehouse.fact_sales(store_key);

-- ------------------------------------------------------------
-- fact_purchases
-- ------------------------------------------------------------
DROP TABLE IF EXISTS warehouse.fact_purchases CASCADE;
CREATE TABLE warehouse.fact_purchases (
    purchase_key        BIGSERIAL      PRIMARY KEY,
    po_date_key         INT            NOT NULL REFERENCES warehouse.dim_date(date_key),
    receiving_date_key  INT            REFERENCES warehouse.dim_date(date_key),
    product_key         INT            NOT NULL REFERENCES warehouse.dim_product(product_key),
    store_key           INT            NOT NULL REFERENCES warehouse.dim_store(store_key),
    vendor_key          INT            REFERENCES warehouse.dim_vendor(vendor_key),
    po_number           INT,
    quantity            INT            NOT NULL DEFAULT 0,
    dollars             NUMERIC(12,2)  NOT NULL DEFAULT 0,
    lead_time_days      INT            -- receiving_date - po_date
);

CREATE INDEX ix_fact_purch_podate  ON warehouse.fact_purchases(po_date_key);
CREATE INDEX ix_fact_purch_product ON warehouse.fact_purchases(product_key);
CREATE INDEX ix_fact_purch_store   ON warehouse.fact_purchases(store_key);
CREATE INDEX ix_fact_purch_vendor  ON warehouse.fact_purchases(vendor_key);

-- ------------------------------------------------------------
-- fact_inventory_snapshot
-- Two rows per SKU-Store: one BEG (2016-01-01) + one END (2016-12-31)
-- ------------------------------------------------------------
DROP TABLE IF EXISTS warehouse.fact_inventory_snapshot CASCADE;
CREATE TABLE warehouse.fact_inventory_snapshot (
    snapshot_key      BIGSERIAL     PRIMARY KEY,
    snapshot_date_key INT           NOT NULL REFERENCES warehouse.dim_date(date_key),
    product_key       INT           NOT NULL REFERENCES warehouse.dim_product(product_key),
    store_key         INT           NOT NULL REFERENCES warehouse.dim_store(store_key),
    on_hand_qty       INT           NOT NULL DEFAULT 0,
    on_hand_cost      NUMERIC(12,2),  -- on_hand_qty * purchase_price
    on_hand_retail    NUMERIC(12,2),  -- on_hand_qty * retail_price
    snapshot_type     CHAR(3)       NOT NULL CHECK (snapshot_type IN ('BEG','END'))
);

CREATE INDEX ix_fact_snap_date    ON warehouse.fact_inventory_snapshot(snapshot_date_key);
CREATE INDEX ix_fact_snap_product ON warehouse.fact_inventory_snapshot(product_key);
CREATE INDEX ix_fact_snap_store   ON warehouse.fact_inventory_snapshot(store_key);
