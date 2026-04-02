# 04 Inventory Performance Analysis

> **Tools:** PostgreSQL 15 · Power BI Desktop  
> **Source:** PwC × Kaggle — Inventory Analysis Case Study (2016–2017, alcohol beverage retailer)

## Project Overview

This project analyses inventory efficiency across a multi-store beverage retailer. Starting from six raw CSV files, we build a dimensional warehouse in PostgreSQL, compute five core KPIs, and surface insights in a multi-page Power BI dashboard.

## Business Questions

| # | Question |
|---|----------|
| 1 | Which product categories turn over fastest / slowest? |
| 2 | Which stores / SKUs are at risk of stockout? |
| 3 | Which SKUs are overstocked and tying up working capital? |
| 4 | What is the optimal reorder point per SKU per store? |
| 5 | How does vendor lead time vary and impact inventory levels? |

## KPIs

| KPI | Formula | Grain |
|-----|---------|-------|
| **Inventory Turnover** | COGS / Avg Inventory (cost) | Product · Store · Period |
| **DSI (Days Sales of Inventory)** | 365 / Inventory Turnover | Product · Store · Period |
| **Stockout Rate** | SKUs with ending onHand = 0 / Total SKUs | Store · Period |
| **Overstock %** | SKUs where onHand > 2× Reorder Point / Total SKUs | Store · Period |
| **Reorder Point** | Avg Daily Sales Qty × Avg Lead Time (days) | Product · Store |

## Data Sources

| File | Description | Grain |
|------|-------------|-------|
| `BegInvFINAL12312016.csv` | Beginning inventory snapshot (2016-01-01) | SKU · Store |
| `EndInvFINAL12312016.csv` | Ending inventory snapshot (2016-12-31) | SKU · Store |
| `SalesFINAL12312016.csv` | Daily sales transactions (2016) | SKU · Store · Date |
| `PurchasesFINAL12312016.csv` | Purchase order line items (2016) | PO Line |
| `InvoicePurchases12312016.csv` | Purchase invoices (2016) | PO · Vendor |
| `2017PurchasePricesDec.csv` | Product master with cost & retail price | SKU |

## Repository Structure

```
04_Inventory_Performance_Analysis/
├── data/
│   ├── raw_review/          # 10-row preview CSV files
│   └── raw/                 # Full source CSVs (gitignored)
├── sql/
│   ├── 01_ddl/
│   │   ├── 01_create_staging.sql
│   │   ├── 02_create_dimensions.sql
│   │   └── 03_create_facts.sql
│   ├── 02_staging/
│   │   └── 01_load_staging.sql
│   ├── 03_transform/
│   │   ├── 01_populate_dimensions.sql
│   │   └── 02_populate_facts.sql
│   ├── 04_kpi/
│   │   ├── 01_inventory_turnover.sql
│   │   ├── 02_dsi.sql
│   │   ├── 03_stockout_rate.sql
│   │   ├── 04_overstock.sql
│   │   └── 05_reorder_point.sql
│   └── 05_analysis/
│       ├── 01_slow_moving_inventory.sql
│       ├── 02_vendor_lead_time.sql
│       └── 03_store_performance.sql
├── powerbi/                 # .pbix file (tracked via Git LFS)
├── docs/
│   └── data_dictionary.md
└── README.md
```

## Star Schema

```
                    dim_date
                       │
dim_vendor ──── fact_sales ──── dim_product
                       │
dim_store ──── fact_purchases
                       │
             fact_inventory_snapshot
```

## Setup Instructions

```bash
# 1. Create database
createdb inventory_analysis

# 2. Run DDL (staging → dimensions → facts)
psql -d inventory_analysis -f sql/01_ddl/01_create_staging.sql
psql -d inventory_analysis -f sql/01_ddl/02_create_dimensions.sql
psql -d inventory_analysis -f sql/01_ddl/03_create_facts.sql

# 3. Load raw CSVs into staging
psql -d inventory_analysis -f sql/02_staging/01_load_staging.sql

# 4. Populate dimensions and facts
psql -d inventory_analysis -f sql/03_transform/01_populate_dimensions.sql
psql -d inventory_analysis -f sql/03_transform/02_populate_facts.sql
```

## Power BI Dashboard Pages

| Page | Focus |
|------|-------|
| 1. Executive Overview | KPI scorecards + trend sparklines |
| 2. Inventory Turnover | Turnover & DSI by category / store |
| 3. Stockout & Risk | Stockout heatmap + at-risk SKU table |
| 4. Overstock & Capital | Overstock $ tied up by vendor / store |
| 5. Reorder Intelligence | ROP table + purchase lead time analysis |
