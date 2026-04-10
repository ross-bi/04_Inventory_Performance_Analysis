-- ============================================================
-- FILE: sql/01_ddl/02_create_staging_tables.sql
-- PURPOSE: Layer 2 - Staging Schema DDL
--          Clean, standardise, validate, annotate DQ flags
-- ============================================================

CREATE SCHEMA IF NOT EXISTS staging;

-- Drop in dependency order
DROP TABLE IF EXISTS staging.stg_inventory_snapshot;
DROP TABLE IF EXISTS staging.stg_purchases;
DROP TABLE IF EXISTS staging.stg_sales;

-- stg_sales will be created via CTAS in 02_elt/02_transform_staging.sql
-- stg_purchases same
-- stg_inventory_snapshot same
-- This file is a placeholder for explicit column-typed DDL if preferred.
-- See 02_elt/02_transform_staging.sql for full CTAS definitions.
