# Inventory Performance Analysis

**PostgreSQL · Power BI · Python · SQL**

---

## Project Overview

This project analyses the full-year 2016 inventory performance of a multi-store liquor
retailer using a real-world dataset from the **PwC × Kaggle Inventory Analysis Case Study**
(~12.8 million sales transactions). Raw CSV data was loaded into **PostgreSQL** via a
Python ELT loader, cleaned through a three-layer architecture (raw → staging → marts),
and visualised in a three-page interactive **Power BI** dashboard.

The goal is to provide data-driven support for **inventory optimisation, dead-stock
reduction, and reorder planning** through structured dimensional modelling, ABC
classification, and KPI analytics.

### Scope

- Load 6 raw CSV files (~12.8 M rows combined) into PostgreSQL via Python (`psycopg2`)
- Execute a full ELT pipeline: raw (TEXT-typed) → staging (type-cast, standardised) → marts (star schema)
- Build a star schema (`dim_product`, `dim_store`, `dim_vendor`, `dim_date` → `fact_sales` + `fact_inventory_snapshot`)
- Implement **Static ABC Classification** in PostgreSQL using window functions to avoid Power BI's 12M-row computation overhead
- Calculate 5 inventory KPIs: Inventory Turnover, DSI, Stockout Rate, Dead Stock %, Reorder Point
- Build a 3-page interactive dashboard in **Power BI** (Import Mode)
- Business insights and actionable recommendations

---

## Dataset

| Item | Description |
|---|---|
| Source | PwC × Kaggle — [Inventory Analysis Case Study](https://www.kaggle.com/bhanupratapbiswas/inventory-analysis-case-study) |
| Full Sales File | [SalesFINAL12312016.csv](https://www.pwc.com/us/en/careers/university_relations/data_analytics_cases_studies/SalesFINAL12312016csv.zip) (12,825,363 rows — download separately) |
| Row Counts | Sales: 12,825,363 / Purchases: 2,372,474 / Beg Inventory: 206,529 / End Inventory: 224,489 |
| Time Range | Full year 2016 (2016-01-01 to 2016-12-31) |
| Stores | 80 stores across multiple cities |
| Products (SKUs) | 12,261 unique brands in `dim_product` |
| Vendors | 132 vendors in `dim_vendor` |
| Key Fields | inventory_id, brand, description, size, store, city, sales_date, sales_quantity, sales_dollars, on_hand, purchase_price |

---

## Tools & Technologies

| Tool | Purpose |
|---|---|
| Python (`psycopg2`, `pandas`, `python-dotenv`) | ELT raw loader — CSV → PostgreSQL `raw` schema |
| PostgreSQL (Standard SQL) | Three-layer ELT, star schema, KPI computation, ABC classification |
| Power BI (Import Mode) | Interactive dashboard & KPI visualisation |
| GitHub | Version control & portfolio documentation |

---

## 1. ELT Pipeline

### Layer 1 — Raw Ingestion (`scripts/01_load_raw.py`)

- Loads all 6 CSV files directly into `raw` schema with **all columns as TEXT** type
- Preserves original data exactly as-is; no transformation at load time
- Uses `psycopg2` with `COPY` for high-performance bulk insert

### Layer 2 — Staging Transformation (`sql/03_staging_transform.sql`)

**Defensive Casting Strategy** — every field uses double `NULLIF` guard:

```sql
CAST(NULLIF(NULLIF(TRIM(sales_quantity), ''), 'Unknown') AS NUMERIC(10,2))
```

| Cleaning Operation | Description |
|---|---|
| Type casting | All TEXT → proper types (NUMERIC, DATE, INTEGER) |
| NULL standardisation | Empty strings and `'Unknown'` values → NULL |
| Vendor name trimming | `TRIM(vendor_name)` — removes trailing whitespace found in source data |
| Gross margin derivation | `(retail_price - purchase_price) / retail_price * 100` computed at staging |
| Carryover invoice flag | `is_carryover_invoice = TRUE` where `invoice_date > 2016-12-31` |
| Post-load row count audit | Row counts validated against raw layer after every INSERT |

### Layer 3 — Marts (Star Schema) (`sql/04_marts_star_schema.sql`)

---

## 2. Data Model (PostgreSQL — Star Schema)

### Schema Diagram

```mermaid
erDiagram
    dim_product {
        int product_sk PK
        int brand
        string description
        string size
        numeric volume_ml
        int classification
        numeric default_retail_price
        numeric default_cost_price
        numeric default_gross_margin_pct
        varchar abc_class
    }
    dim_store {
        int store_sk PK
        int store_number
        string city
    }
    dim_vendor {
        int vendor_sk PK
        int vendor_number
        string vendor_name
    }
    dim_date {
        date date_key PK
        int year
        int quarter
        int month
        int week
        string month_name
        string quarter_name
    }
    fact_sales {
        int product_sk FK
        int store_sk FK
        int vendor_sk FK
        string inventory_id
        date sales_date FK
        numeric sales_quantity
        numeric sales_price
        numeric sales_dollars
        numeric excise_tax
        numeric estimated_cogs
    }
    fact_inventory_snapshot {
        int product_sk FK
        int store_sk FK
        string inventory_id
        date snapshot_date
        string snapshot_type
        numeric quantity_on_hand
        numeric snapshot_price
        numeric total_inventory_value
    }

    dim_product ||--o{ fact_sales : "sold"
    dim_store   ||--o{ fact_sales : "at"
    dim_vendor  ||--o{ fact_sales : "supplied by"
    dim_product ||--o{ fact_inventory_snapshot : "stocked as"
    dim_store   ||--o{ fact_inventory_snapshot : "held at"
    dim_date    ||--o{ fact_sales : "sales_date"
    dim_date    ||--o{ fact_inventory_snapshot : "snapshot_date"

```

### Table Descriptions

| Table | Type | Description | Design Notes |
|---|---|---|---|
| `dim_product` | Dimension | 12,261 unique SKUs with brand, description, size, pricing | `abc_class` intentionally NULL at creation; back-filled after `fact_sales` via CTE UPDATE |
| `dim_store` | Dimension | 80 stores with city names | City sourced from beg/end inventory; missing from sales table |
| `dim_vendor` | Dimension | 132 vendors consolidated from 4 source tables | UNION of purchases, sales, invoices, and purchase prices. **Connects to `fact_sales` only** — `fact_inventory_snapshot` records stock positions at Store × Product × Date grain and does not carry `vendor_sk` by design. Excluded from all Power BI dashboard slicers; vendor-level procurement analysis is planned as a future enhancement. |
| `dim_date` | Dimension | Full 2016 calendar (366 days) | Year / Quarter / Month / Week derived fields for Power BI slicers |
| `fact_sales` | Fact | 12,825,363 sales transaction rows | `estimated_cogs = sales_quantity × default_cost_price` |
| `fact_inventory_snapshot` | Fact | BEGINNING + ENDING snapshot rows (431,018 total) | Two `snapshot_type` values enable single-table Turnover/DSI calculation |

---

## 3. ABC Classification Design

> **Portfolio Highlight — Solving a Real Engineering Constraint**

**Problem:** Power BI cannot efficiently compute running-total ABC classification
across 12M rows in Import Mode. DAX `RANKX` + cumulative `CALCULATE` at SKU level
causes report refresh timeouts.

**Solution — Static ABC in PostgreSQL (Two-Phase Approach):**

```sql
-- Phase A: Aggregate revenue per product
-- Phase B: Running cumulative % with window function
-- Phase C: Assign A/B/C label
-- Phase D: Single UPDATE pass back to dim_product

WITH product_revenue AS (
    SELECT product_sk, SUM(sales_dollars) AS total_sales_dollars
    FROM marts.fact_sales GROUP BY product_sk
),
running_total AS (
    SELECT product_sk,
        ROUND(100.0 * SUM(total_sales_dollars) OVER (ORDER BY total_sales_dollars DESC
              ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
              / NULLIF(SUM(total_sales_dollars) OVER (), 0), 4) AS cumulative_pct
    FROM product_revenue
),
abc_labels AS (
    SELECT product_sk,
        CASE WHEN cumulative_pct <= 80 THEN 'A'
             WHEN cumulative_pct <= 95 THEN 'B'
             ELSE 'C' END AS abc_class
    FROM running_total
)
UPDATE marts.dim_product dp
SET abc_class = al.abc_class
FROM abc_labels al WHERE dp.product_sk = al.product_sk;
```

| Class | Threshold | Actual SKU Count | Actual SKU% | Revenue% |
|---|---|---|---|---|
| A | Cumulative ≤ 80% | 1,575 | 12.85% | 80% |
| B | Cumulative ≤ 95% | 2,101 | 17.14% | 15% |
| C | Cumulative > 95% | 7,561 | 61.67% | 5% |
| Unclassified (no sales) | — | 1,024 | 8.35% | — |

---

## 4. KPI Definitions & Results

### KPI Formulas

| KPI | Formula | Source Tables |
|---|---|---|
| **Inventory Turnover** | `COGS / ((Beg Inventory Value + End Inventory Value) / 2)` | `fact_sales`, `fact_inventory_snapshot` |
| **DSI (Days Sales of Inventory)** | `365 / Inventory Turnover` | Derived |
| **Stockout Rate** | `SKU-Store combos with ending on_hand = 0 / Total SKU-Store combos` | `fact_inventory_snapshot` |
| **Dead Stock %** | `SKU-Store with end_qty > 0 AND zero sales in 2016 / Total positions` | `fact_inventory_snapshot`, `fact_sales` |
| **Gross Margin %** | `(Retail Price − Cost Price) / Retail Price × 100` | `dim_product` |

### KPI Summary (2016 Full Year)

| KPI | Value | Benchmark |
|---|---|---|
| Total Revenue | $452,062,952 | — |
| Total COGS (estimated) | $313,385,300 | — |
| Inventory Turnover | **4.24x** | Liquor retail ~4–6x typical ✅ |
| DSI | **86 days** | Lower = more efficient |
| Stockout Rate | **3.22%** | Target < 5% ✅ |
| Dead Stock % | **2.56%** | Target < 10% ✅ |
| Avg Gross Margin (Class A) | **31.69%** | — |

---

## 5. SQL Analysis Pipeline

| SQL File | Purpose | Key Operations |
|---|---|---|
| `00_schema_setup.sql` | Schema & raw table DDL | Creates `raw`, `staging`, `marts` schemas; all raw columns TEXT |
| `01_raw_columns_check.sql` | Column header audit | Verifies actual column names against expectations |
| `02_validate_raw.sql` | 7-section raw data QA | NULL checks, business rules, date range, duplicate detection, referential integrity |
| `03_staging_transform.sql` | Staging layer ELT | Defensive casting, NULL standardisation, gross margin derivation, row count audit |
| `04_marts_star_schema.sql` | Star schema + ABC | Dim/Fact creation with surrogate keys; 4-phase static ABC classification |
| `05_marts_dim_date.sql` | Date dimension | Full 2016 calendar with Year/Quarter/Month/Week attributes |
| `analysis/A. overview & Inventory Turnover & DSI.sql` | KPI baseline analysis | Table row counts, revenue summary, and Turnover/DSI calculation |
| `analysis/B. Stockout Rate & Overstock (Dead Stock).sql` | Inventory health | Stockout rate and dead stock % by SKU-store position |
| `analysis/C. ABC Classification Distribution.sql` | ABC breakdown | SKU count, SKU%, and avg gross margin by A/B/C class |


### Data Validation Highlights (`02_validate_raw.sql`)

| Check | Finding |
|---|---|
| NULL primary keys | 0 NULL `inventory_id` across all tables |
| Negative quantities / dollars | 0 rows in `raw_sales` |
| Price calc mismatch (`raw_purchase_prices`) | 12,260 rows where retail price ≠ purchase price (expected — margin spread) |
| Date out-of-range | Sales: 0 rows outside 2016; Invoice purchases: 140 carryover rows (flagged & retained) |
| Referential integrity | 64,044 sales inventory_ids not in beg inventory; 50,368 not in end inventory (new products launched mid-year — expected) |
| Vendor trailing whitespace | Found in 20+ vendors; resolved via `TRIM(vendor_name)` in staging |

---

## 6. Power BI Dashboard (3 Pages)

### Page 1: Executive Overview
<img src="powerbi/screenshots/Page1.png" alt="Executive Overview Dashboard" width="100%">

**KPI Cards (top row)**
- **Inventory Turnover — 4.24x**: Annual stock turnover calculated as COGS ÷ Average Inventory
  (beginning + ending ÷ 2). Benchmark for liquor retail is 4–6x; result is within healthy range.
- **Days Sales of Inventory (DSI) — 86 days**: Derived as 365 ÷ Inventory Turnover. Indicates
  ~3 months of stock on hand across all stores.
- **Stockout Rate — 3.22%**: Proportion of ending-inventory SKU-store positions where
  quantity_on_hand = 0. Below the 5% target threshold.
- **Dead Stock % of Total Inventory — 1.85%**: Share of ending inventory value tied to SKUs
  with zero sales in the past 90 days. Threshold annotation set at 5.0%.

**Stockout Rate by Store (Clustered Column Chart)**
Displays Stockout Rate for each store, sorted descending. Store 46 shows a near-100%
stockout rate, far exceeding all other stores, signalling a critical replenishment failure.
Most stores cluster near 0–5%, confirming the aggregate rate is driven by a small number
of outlier stores.

**Monthly Revenue vs COGS (Dual-Line Chart)**
Full-year 2016 monthly trend showing Total Revenue (teal) and Total COGS (orange) side by
side. Revenue peaks in July (~ $49M) and December (~ $52M), with the annual trough in
February (~$29M). The consistent gap between the two lines reflects a stable gross margin
across all 12 months.

**Dead Stock by ABC (Horizontal Bar Chart)**
Compares Dead Stock Value (90 Days) across ABC classes. Class C dominates at ~$1.0M,
followed by Unclassified at ~$0.5M, while Class B is minimal. Confirms that slow-moving
long-tail SKUs are the primary source of stranded inventory capital.

**Store Performance by ABC / Unclassified Segment (Matrix)**
Drillable matrix with rows: Store Number → ABC Class Display. Columns: Total Revenue,
Ending Inventory Value, Inventory Turnover, Days Sales of Inventory (DSI), Stockout Rate.
Conditional formatting highlights underperforming cells (e.g. Store 76 Unclassified shows
DSI = 232 days in amber, Stockout Rate = 25.53%). Enables rapid identification of which
store–segment combinations require immediate attention.

### Page 2: Inventory Risk Analysis
<img src="powerbi/screenshots/Page2.png" alt="Inventory Risk Analysis Dashboard" width="100%">

**KPI Cards (top row)**
- **Dead Stock Value (90 Days) — $1.47M**: Total ending inventory value for SKU-store
  positions with zero sales in the trailing 90 days (Oct–Dec 2016).
- **Dead Stock SKU Count — 591**: Number of distinct SKUs flagged as dead stock across
  all stores.
- **Out of Stock Records — 13K**: Count of ending-inventory snapshot records where
  quantity_on_hand ≤ 0, representing confirmed stockout positions.
  > **Note — Dead Stock metric definitions differ between SQL analysis and Power BI dashboard:**
> The SQL analysis in `Key Findings` (Section 7) reports **5,755 positions / 77,785 units**
> of dead stock, defined as SKU-store positions with **zero sales across the full year 2016**
> (static query against `fact_sales` + `fact_inventory_snapshot`).
> The Power BI KPI cards above report **$1.47M / 591 SKUs**, defined as positions with
> **zero sales in the trailing 90 days (Oct–Dec 2016 only)** — a rolling DAX measure
> intentionally designed to surface actionable near-term clearance candidates.
> Both metrics are correct; they answer different business questions:
> SQL = full-year exposure audit; Power BI = actionable 90-day clearance list.

**Stockout Rate vs Dead Stock % — Store Risk Quadrant (Scatter Chart)**
Each bubble represents one store; bubble size encodes Ending Inventory Value. X-axis =
Stockout Rate; Y-axis = Dead Stock % of Total Inventory. Reference lines divide the chart
into four quadrants (vertical: Stockout Rate = 5%; horizontal: Dead Stock % = 3%).
Stores in the upper-right quadrant face simultaneous high stockout and high dead stock —
the most critical management risk. Most stores cluster in the lower-left (healthy zone),
while a handful of outliers in the upper regions warrant targeted intervention.

**Dead Stock Value (90 Days) by Store Number (Horizontal Bar Chart)**
Ranks stores by dead stock exposure. Store 50 leads at ~ $0.52M, followed by Store 69
(~ $0.44M) and Store 34 (~ $0.42M). Top 5 stores account for a disproportionate share of
total dead stock value, enabling focused markdown or clearance decisions.

**Risk Detail Table**
Row-level breakdown sorted by Dead Stock Value descending. Columns: Store Number, Brand,
ABC Class Display, Current Stock Qty, Sales Qty Last 90 Days, Dead Stock Value (90 Days),
Inventory Status, Stock Record Status, SKU Lifecycle Status.
- **Inventory Status** (🟠 Dead Stock / 🔴 Out of Stock / 🟢 Healthy) — flags each
  position's risk category.
- **Stock Record Status** (Has Snapshot / ⚠️ No Snapshot Has Sales) — identifies data
  coverage gaps where sales exist but no ending inventory record is present.
- **SKU Lifecycle Status** (Stable / New Introduction / Sold Out) — classifies each
  brand-store combination by its beginning vs ending snapshot pattern.
  Top rows show Class B/C SKUs at stores 50, 76, 34, 69 with Dead Stock Value ranging
  from ~$10K to ~$20K per position.


### Page 3: Replenishment & ABC Prioritization
<img src="powerbi/screenshots/Page3.png" alt="Replenishment & ABC Prioritization Dashboard" width="100%">

**KPI Cards (top row)**
- **Reorder SKU Count — 2,639**: Total number of distinct SKUs currently at or below their
  Reorder Point (Reorder Alert = "🟡 Reorder Now"), requiring immediate replenishment action.
- **Avg Daily Sales Qty — 89.94K**: Portfolio-wide average units sold per day, used as the
  demand input for Reorder Point and Safety Stock calculations.
- **Ending Inventory Value — $79.70M**: Total ending inventory value across all stores,
  providing context for the scale of inventory at risk.

**Stock vs ROP Gap by Brand (Horizontal Bar Chart)**
Plots Current Stock Qty minus Reorder Point Qty for each store-brand combination. Positive
values (right of zero) indicate adequate buffer; negative values (left of zero) signal
that stock has already fallen below the reorder threshold. Store 46, Brand 381 shows the
largest positive gap (~+250K), while several brands on the left show negative gaps requiring
urgent action. Chart axis Y shows store_number, enabling store-level drill-down.

**Reorder SKU Count by ABC Class Display (Clustered Column Chart)**
Compares the number of SKUs requiring reorder across ABC classes. Class C dominates at
~2,500+ SKUs, reflecting the large long-tail catalogue. Class B and A have markedly fewer
reorder-flagged SKUs, consistent with their higher velocity and more active replenishment
management. Highlights that long-tail C-class inventory management is the primary
operational burden.

**Replenishment Prioritization Matrix — Sorted by Urgency (Matrix)**
Drillable matrix with hierarchy: ABC Priority Group → Brand → Store Number. Sorted by
Reorder Alert urgency (Out of Stock → Reorder Now → Low Stock → OK). Columns:
Current Stock Qty, Avg Daily Sales Qty, Safety Stock Qty, Reorder Point Qty, Reorder Alert,
Days of Stock Remaining, Stock vs ROP Gap.
Top rows show A-Critical brand 381 across multiple stores all flagged 🔴 Out of Stock with
Current Stock = 0.00, Days of Stock Remaining = 0.00, and Stock vs ROP Gap ranging from
−19 to −51 — confirming these as the highest-priority replenishment actions.
Conditional formatting on Stock vs ROP Gap renders negative values in red to surface the
most critical shortfalls at a glance.

> **Design Note — `dim_vendor` excluded from dashboard slicers:**
> `dim_vendor` is modelled and connected to `fact_sales` in PostgreSQL and Power BI.
> However, all five inventory KPIs (Inventory Turnover, DSI, Stockout Rate, Dead Stock %,
> Reorder Point) are derived from `fact_inventory_snapshot`, which records stock positions
> at **Store × Product × Date grain** and carries no `vendor_sk`.
> A vendor slicer would be inert on inventory-focused pages — this exclusion is intentional,
> not an omission. Vendor-level procurement analysis is planned as a future enhancement.

Dashboard PDF export: [`powerbi/dashboard.pdf`](./powerbi/dashboard.pdf)

---

## Key Findings

### Inventory KPIs

| Metric | Value | Insight |
|---|---|---|
| Inventory Turnover | 4.24x | Within benchmark range (4–6x) for liquor retail; slight room for improvement |
| DSI | 86 days | ~3 months of stock on hand; C-class SKUs likely dragging this higher |
| Stockout Rate | 3.22% | Below 5% target — healthy supply coverage overall |
| Dead Stock % | 2.56% | 5,755 positions / 77,785 units with **zero sales across full year 2016** (SQL static audit). Power BI dashboard reports $1.47M / 591 SKUs on a **rolling 90-day window** — see note in Section 6 Page 2. |

### ABC Classification

| Class | SKU Count | SKU% | Avg Gross Margin% | Revenue Contribution |
|---|---|---|---|---|
| A | 1,575 | 12.85% | 31.69% | 80% |
| B | 2,101 | 17.14% | 33.28% | 15% |
| C | 7,561 | 61.67% | 33.81% | 5% |
| Unclassified | 1,024 | 8.35% | 32.74% | — |

---

## Business Recommendations

1. **Protect Class A SKU availability — especially top 5 products** — 1,575 SKUs (12.85% of catalogue) generate 80% of $452M revenue. Jack Daniels No 7 ($5.1M) and Tito's Vodka ($4.8M) alone represent over 2% of total revenue each. At 2016 weekly run-rates, a single week of stockout on Jack Daniels No 7 alone represents ~$98K in lost sales; Tito's Handmade Vodka adds another ~$93K — together ~$191K/week at risk. Implement automated reorder triggers at 2× average weekly velocity.



2. **Reduce DSI from 86 days toward the 60–70 day range** — the current 86-day DSI is above the efficient liquor retail target. With ending inventory at $79.7M (+17.1% vs beginning), inventory growth outpaced sales growth. Focus purchase order reductions on the 7,561 C-class SKUs, which contribute only 5% of revenue but represent 61.67% of the product catalogue.


3. **Investigate seasonal demand and pre-position stock ahead of peak months** — December ($52.3M) and July ($49.7M) are the two highest-revenue months, together representing 22.6% of annual sales. February ($28.9M) is the annual trough. A forward-buying strategy in November and June for Class A SKUs, combined with purchase freezes in January for C-class items, would reduce DSI while protecting availability during peaks.

4. **Monitor the 3.22% stockout rate at store level** — while the aggregate rate is within target, Doncaster stores #76 and #73 (top 2 by revenue at $25.5M and $21.7M) likely have disproportionate impact if stocked out. Store-level drill-down in the Power BI Inventory Health page enables targeted replenishment prioritisation.

---

## Data Engineering Notes

### Handling the 12.8M Row Sales File

The full `SalesFINAL12312016.csv` contains **12,825,363 rows** but standard tools (Excel, pgAdmin import wizard) cap at ~1M rows. This project resolves this using a Python `psycopg2` bulk loader with chunked reads:

```python
# scripts/01_load_raw.py
for chunk in pd.read_csv(filepath, chunksize=100_000, dtype=str):
    # Stream directly into PostgreSQL raw schema
```

The full file must be downloaded from the [PwC source](https://www.pwc.com/us/en/careers/university_relations/data_analytics_cases_studies/SalesFINAL12312016csv.zip) and placed in `data/raw/` before running the loader.

---

## How to Reproduce

**Prerequisites**: Python 3.8+, PostgreSQL 14+, Power BI Desktop

1. Download raw data files from [Kaggle](https://www.kaggle.com/bhanupratapbiswas/inventory-analysis-case-study) + [PwC full sales file](https://www.pwc.com/us/en/careers/university_relations/data_analytics_cases_studies/SalesFINAL12312016csv.zip), place in `data/raw/`
2. Install dependencies
   ```bash
   pip install pandas sqlalchemy psycopg2-binary python-dotenv
   ```
3. Configure database connection
   ```bash
   cp .env.example .env
   # Edit .env with your PostgreSQL credentials
   ```
4. Run ELT pipeline in order:
   ```bash
   # Step 1: Create schemas & raw tables
   psql -f sql/00_schema_setup.sql

   # Step 2: Load raw CSVs into PostgreSQL
   python scripts/01_load_raw.py

   # Step 3: Validate raw data
   psql -f sql/02_validate_raw.sql

   # Step 4: Staging transformation
   psql -f sql/03_staging_transform.sql

   # Step 5: Build star schema + ABC classification
   psql -f sql/04_marts_star_schema.sql

   # Step 6: Build date dimension
   psql -f sql/05_marts_dim_date.sql
   ```
5. Run KPI analysis queries (optional — outputs already in `output/analysis/`):
   ```bash
   psql -f "sql/analysis/A. overview & Inventory Turnover & DSI.sql"
   psql -f "sql/analysis/B. Stockout Rate & Overstock (Dead Stock).sql"
   psql -f "sql/analysis/C. ABC Classification Distribution.sql"
   ```
6. Open Power BI Desktop, connect to PostgreSQL `marts` schema, refresh data

---

## Project Structure
```
04_Inventory_Performance_Analysis/
├── README.md
├── data/
│   ├── raw/                          # Full CSVs (gitignored — not committed)
│   └── raw_review/                   # 100-row preview of each source file
├── scripts/
│   └── 01_load_raw.py                # Python bulk loader (CSV → raw schema)
├── sql/
│   ├── 00_schema_setup.sql           # Schema creation & raw table DDL
│   ├── 01_raw_columns_check.sql      # Column header audit
│   ├── 02_validate_raw.sql           # 7-section raw data validation
│   ├── 03_staging_transform.sql      # Staging ELT (type casting, NULL handling)
│   ├── 04_marts_star_schema.sql      # Star schema + static ABC classification
│   ├── 05_marts_dim_date.sql         # Date dimension
│   └── analysis/                     # KPI & business analysis queries
├── output/
│   ├── mart_review/                  # 100-row previews of mart tables
│   ├── sql.02_validate_raw/          # Validation query outputs (CSV)
│   └── analysis/                     # KPI analysis query outputs (CSV)
├── powerbi/
│   ├── dashboard.pdf                 # Dashboard PDF export
│   └── screenshots/                  # Page1.png / Page2.png / Page3.png
├── powerbi_design.ipynb              # Power BI design specifications & DAX
├── log.ipynb                         # Development log & engineering decisions
├── .env.example                      # Database connection template
└── LICENSE
```

---

## Author

Ross Tang | [GitHub](https://github.com/ross-bi)

## License

This project is licensed under the [MIT License](./LICENSE).
