# 04 Inventory Performance Analysis

## Project Overview

End-to-end inventory analytics project built with **PostgreSQL** and **Power BI**, analysing the operational performance of **Bibitor LLC** — a fictional 80-location liquor retail chain in the state of Lincoln.

The goal is to surface actionable insights across five KPIs: inventory turnover, days sales of inventory (DSI), stockout rate, overstock percentage, and reorder point.

---

## Data Source

**PwC x Kaggle — Inventory Analysis Case Study**

> Bibitor, LLC — a liquor store chain with ~80 locations and total annual sales in excess of $450 million. Data covers a 12-month period of beginning/ending inventory, purchases, and sales.

| File | Description | Role |
|------|-------------|------|
| `BegInvFINAL12312016.csv` | Beginning inventory snapshot per Store x SKU | Period-open stock level |
| `EndInvFINAL12312016.csv` | Ending inventory snapshot per Store x SKU | Period-close stock level |
| `PurchasesFINAL12312016.csv` | Every purchase / receiving record | Replenishment transactions |
| `SalesFINAL12312016.csv` | Daily sales transactions | Demand transactions |
| `InvoicePurchases12312016.csv` | Purchase invoices with approval & freight details | Lead time calculation |
| `Vendor_Purchase_Prices_Dec2017.csv` | Vendor reference price list | dim_vendor enrichment |

Download from [Kaggle](https://www.kaggle.com/datasets/bhanupratapbiswas/inventory-analysis-case-study) and place raw CSV files in `data/raw/`.

---

## KPIs

| KPI | Formula | Business Question |
|-----|---------|------------------|
| **Inventory Turnover** | COGS / Average Inventory | How efficiently is stock being sold? |
| **Days Sales of Inventory (DSI)** | 365 / Inventory Turnover | How many days to sell current stock? |
| **Stockout Rate** | SKUs with Ending Inventory = 0 / Total SKUs | What proportion of products ran out? |
| **Overstock %** | SKUs where Ending Inv > Reorder Point x 1.5 / Total SKUs | What proportion is over-stocked? |
| **Reorder Point** | Avg Daily Sales x Lead Time + Safety Stock | When should replenishment be triggered? |

---

## Tools & Stack

| Layer | Tool |
|-------|------|
| Data Warehouse | PostgreSQL 16 |
| Data Modelling | Star Schema (Kimball) |
| Transformation | SQL (Views + CTEs) |
| Visualisation | Power BI Desktop |
| Version Control | Git / GitHub |

---

## Repository Structure

```
04_Inventory_Performance_Analysis/
├── data/
│   └── raw/                          # Place downloaded CSVs here (gitignored)
├── sql/
│   ├── 01_create_schema.sql          # DDL: dimension + fact tables
│   ├── 02_load_staging.sql           # Staging table creation & COPY commands
│   ├── 03_transform_dimensions.sql   # Populate dim_* tables
│   ├── 04_transform_facts.sql        # Populate fact_* tables
│   ├── 05_create_views.sql           # KPI analytical views
│   └── 06_kpi_queries.sql            # Standalone KPI validation queries
├── powerbi/
│   └── inventory_dashboard.pbix      # Power BI report file
├── docs/
│   ├── schema_erd.png                # ERD diagram
│   └── data_dictionary.md            # Column definitions
└── README.md
```

---

## Schema Design

See `sql/01_create_schema.sql` for full DDL.

### Dimension Tables

| Table | Grain | Key Columns |
|-------|-------|-------------|
| `dim_product` | 1 row per SKU | `product_key`, `brand`, `description`, `size`, `classification` |
| `dim_store` | 1 row per store | `store_key`, `store_id`, `city`, `state` |
| `dim_vendor` | 1 row per vendor | `vendor_key`, `vendor_number`, `vendor_name` |
| `dim_date` | 1 row per calendar day | `date_key`, `full_date`, `year`, `quarter`, `month`, `week_of_year` |

### Fact Tables

| Table | Grain | Key Measures |
|-------|-------|-------------|
| `fact_inventory_snapshot` | 1 row per store x product x period | `beginning_qty`, `ending_qty`, `unit_price` |
| `fact_sales` | 1 row per store x product x day | `sales_qty`, `sales_dollars`, `sales_price`, `excise_tax` |
| `fact_purchases` | 1 row per purchase transaction | `purchase_qty`, `purchase_dollars`, `purchase_price`, `receiving_date` |

---

## Getting Started

```bash
# 1. Clone the repository
git clone https://github.com/ross-bi/04_Inventory_Performance_Analysis.git

# 2. Download CSVs from Kaggle and place in data/raw/

# 3. Create database
psql -U postgres -c "CREATE DATABASE inventory_analysis;"

# 4. Run SQL scripts in order
psql -U postgres -d inventory_analysis -f sql/01_create_schema.sql
psql -U postgres -d inventory_analysis -f sql/02_load_staging.sql
psql -U postgres -d inventory_analysis -f sql/03_transform_dimensions.sql
psql -U postgres -d inventory_analysis -f sql/04_transform_facts.sql
psql -U postgres -d inventory_analysis -f sql/05_create_views.sql

# 5. Open powerbi/inventory_dashboard.pbix in Power BI Desktop
```

---

## Portfolio Context

This is **Project 04** in the BI portfolio:

| # | Project | Focus |
|---|---------|-------|
| 01 | Superstore Sales Analysis | Star schema, dimensional modelling |
| 02 | Ecommerce Customer Journey | dbt, funnel analysis |
| 03 | Traffic Sources & Ad ROI | GA4, campaign performance |
| **04** | **Inventory Performance** | **Inventory KPIs, replenishment logic** |
