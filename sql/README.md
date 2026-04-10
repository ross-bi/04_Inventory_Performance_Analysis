# SQL Scripts — Inventory Performance Analysis

## ELT Pipeline Architecture

```
CSV Files (raw/)  →  raw schema  →  staging schema  →  warehouse schema
                        (L1)             (L2)               (L3)
```

## Execution Order

```bash
# Step 1: Create all schemas & tables
psql -d your_db -f sql/01_ddl/01_create_raw_tables.sql
psql -d your_db -f sql/01_ddl/03_create_warehouse_tables.sql

# Step 2: Load raw CSV data
# Edit /path/to/data/raw/ in the file first!
psql -d your_db -f sql/02_elt/01_load_raw.sql

# Step 3: Transform to staging (cleanse + DQ flags)
psql -d your_db -f sql/02_elt/02_transform_staging.sql

# Step 4: Load warehouse (star schema)
psql -d your_db -f sql/02_elt/03_load_warehouse.sql

# Step 5: Run data quality audit
psql -d your_db -f sql/03_quality/01_data_quality_checks.sql

# Step 6: Create KPI views for Power BI
psql -d your_db -f sql/04_analysis/01_kpi_views.sql
```

## Schema Overview

### Layer 1 — `raw`
| Table | Source File | Description |
|---|---|---|
| `raw.sales` | SalesFINAL12312016.csv | Daily sales transactions |
| `raw.purchases` | PurchasesFINAL12312016.csv | Purchase order lines |
| `raw.beg_inventory` | BegInvFINAL12312016.csv | Period-start inventory snapshot |
| `raw.end_inventory` | EndInvFINAL12312016.csv | Period-end inventory snapshot |
| `raw.invoice_purchases` | InvoicePurchases12312016.csv | Vendor invoice summaries |
| `raw.purchase_prices` | 2017PurchasePricesDec.csv | Reference price list |

### Layer 2 — `staging`
| Table | Key Transformations |
|---|---|
| `stg_sales` | Decompose inventory_id, DQ flags, date parts |
| `stg_purchases` | Decompose inventory_id, lead time, payment days |
| `stg_inventory_snapshot` | Union beg+end, snapshot_type flag |

### Layer 3 — `warehouse` (Star Schema)
| Table/View | Type | Description |
|---|---|---|
| `dim_date` | Dimension | Calendar attributes |
| `dim_product` | Dimension | SKU / brand details |
| `dim_store` | Dimension | Store details |
| `dim_vendor` | Dimension | Vendor details |
| `fact_inventory` | Fact | KPI measures by SKU x Store x Month |
| `vw_inventory_turnover` | View | Turnover + DSI + health classification |
| `vw_stockout_analysis` | View | Stockout flag + lost revenue estimate |
| `vw_overstock_analysis` | View | Overstock flag + months of supply |
| `vw_reorder_point` | View | Reorder flag + suggested order qty |
| `vw_kpi_summary` | View | Executive-level KPI aggregates |

## KPI Formulas

| KPI | Formula |
|---|---|
| Inventory Turnover | `Sales Qty / Avg Inventory` |
| DSI | `(Avg Inventory / Sales Qty) × 365` |
| Stockout Rate | `Stockout SKUs / Total SKUs × 100` |
| Overstock % | `Overstock SKUs / Total SKUs × 100` |
| Reorder Point | `Avg Daily Sales × 7 (lead time days)` |
| Safety Stock | `Avg Daily Sales × 14 days` |

## Data Quality Flags

| Flag | Meaning |
|---|---|
| `VALID` | Passes all checks |
| `INVALID_QTY` | Quantity ≤ 0 |
| `INVALID_AMT` | Amount ≤ 0 |
| `INVALID_PRICE` | Unit price ≤ 0 |
| `AMOUNT_MISMATCH` | `dollars ≠ price × qty` (tolerance 0.05) |
| `BAD_INVENTORY_ID` | Non-numeric brand segment in inventory_id |
| `RECEIVING_BEFORE_PO` | Receiving date earlier than PO date |
| `NEGATIVE_STOCK` | on_hand < 0 |
