# Data Dictionary — 04 Inventory Performance Analysis

## Source Data: PwC x Kaggle — Bibitor LLC

Bibitor, LLC is a fictional liquor store chain (~80 stores, $450M+ annual sales) in the state of Lincoln. Data period: 12 months (2016 fiscal year).

---

## Staging Tables

### `staging.stg_beg_inventory`
| Column | Type | Description |
|--------|------|-------------|
| InventoryId | VARCHAR | Composite key (Store-Brand) |
| Store | INT | Store number |
| City | VARCHAR | Store city |
| Brand | INT | Brand / product code |
| Description | VARCHAR | Product name |
| Size | VARCHAR | Bottle size (e.g. 750mL) |
| onHand | NUMERIC | Units on hand at period open |
| Price | NUMERIC | Retail unit price |
| startDate | VARCHAR | Period open date |

### `staging.stg_end_inventory`
| Column | Type | Description |
|--------|------|-------------|
| InventoryId | VARCHAR | Composite key (Store-Brand) |
| Store | INT | Store number |
| City | VARCHAR | Store city |
| Brand | INT | Brand / product code |
| Description | VARCHAR | Product name |
| Size | VARCHAR | Bottle size |
| onHand | NUMERIC | Units on hand at period close |
| Price | NUMERIC | Retail unit price |
| endDate | VARCHAR | Period close date |

### `staging.stg_purchases`
| Column | Type | Description |
|--------|------|-------------|
| InventoryId | VARCHAR | Composite key |
| Store | INT | Store number |
| Brand | INT | Brand code |
| Description | VARCHAR | Product name |
| Size | VARCHAR | Bottle size |
| VendorNumber | INT | Supplier ID |
| VendorName | VARCHAR | Supplier name |
| PONumber | INT | Purchase order number |
| PODate | VARCHAR | PO creation date |
| ReceivingDate | VARCHAR | Date goods received |
| InvoiceDate | VARCHAR | Invoice date |
| PayDate | VARCHAR | Payment date |
| Quantity | NUMERIC | Units received |
| Dollars | NUMERIC | Total purchase value |
| Classification | VARCHAR | Product category (WINE / SPIRITS) |

### `staging.stg_sales`
| Column | Type | Description |
|--------|------|-------------|
| InventoryId | VARCHAR | Composite key |
| Store | INT | Store number |
| Brand | INT | Brand code |
| Description | VARCHAR | Product name |
| Size | VARCHAR | Bottle size |
| VendorNo | INT | Supplier ID |
| VendorName | VARCHAR | Supplier name |
| Volume | NUMERIC | Volume in litres |
| Classification | VARCHAR | Product category |
| SalesQuantity | NUMERIC | Units sold |
| SalesDollars | NUMERIC | Revenue |
| SalesPrice | NUMERIC | Unit selling price |
| SalesDate | VARCHAR | Transaction date |
| ExciseTax | NUMERIC | Tax component |
| County | INT | County code |
| City | VARCHAR | Store city |

### `staging.stg_invoice_purchases`
| Column | Type | Description |
|--------|------|-------------|
| VendorNumber | INT | Supplier ID |
| VendorName | VARCHAR | Supplier name |
| InvoiceDate | VARCHAR | Invoice date |
| PONumber | INT | Links to stg_purchases |
| PODate | VARCHAR | PO creation date |
| PayDate | VARCHAR | Payment date |
| Quantity | NUMERIC | Units invoiced |
| Dollars | NUMERIC | Invoice value |
| Freight | NUMERIC | Shipping cost |
| Approval | VARCHAR | PO approval date — used to calculate Lead Time |

---

## Dimension Tables

### `dim_date`
| Column | Type | Description |
|--------|------|-------------|
| date_key | INT | Surrogate key (YYYYMMDD) |
| full_date | DATE | Calendar date |
| year | SMALLINT | Calendar year |
| quarter | SMALLINT | Quarter (1-4) |
| month | SMALLINT | Month (1-12) |
| month_name | VARCHAR | Month name |
| week_of_year | SMALLINT | ISO week number |
| day_of_week | SMALLINT | ISO day (1=Mon ... 7=Sun) |
| day_name | VARCHAR | Day name |
| is_weekend | BOOLEAN | TRUE for Saturday/Sunday |

### `dim_product`
| Column | Type | Description |
|--------|------|-------------|
| product_key | SERIAL | Surrogate key |
| brand | VARCHAR | Brand code (from source) |
| description | VARCHAR | Product name |
| size | VARCHAR | Bottle size |
| classification | VARCHAR | WINE / SPIRITS |
| volume_ml | NUMERIC | Derived volume in mL |

### `dim_store`
| Column | Type | Description |
|--------|------|-------------|
| store_key | SERIAL | Surrogate key |
| store_id | INT | Source store number |
| city | VARCHAR | Store city |
| state | CHAR(2) | State code (LN = Lincoln) |

### `dim_vendor`
| Column | Type | Description |
|--------|------|-------------|
| vendor_key | SERIAL | Surrogate key |
| vendor_number | INT | Source vendor ID |
| vendor_name | VARCHAR | Supplier name |

---

## Fact Tables

### `fact_inventory_snapshot`
| Column | Type | Description |
|--------|------|-------------|
| snapshot_id | BIGSERIAL | Primary key |
| date_key | INT | FK -> dim_date |
| store_key | INT | FK -> dim_store |
| product_key | INT | FK -> dim_product |
| period_type | CHAR(3) | 'BEG' or 'END' |
| on_hand_qty | NUMERIC | Units on hand |
| unit_price | NUMERIC | Retail price at snapshot |
| inventory_value | NUMERIC | on_hand_qty x unit_price |

### `fact_sales`
| Column | Type | Description |
|--------|------|-------------|
| sale_id | BIGSERIAL | Primary key |
| date_key | INT | FK -> dim_date |
| store_key | INT | FK -> dim_store |
| product_key | INT | FK -> dim_product |
| vendor_key | INT | FK -> dim_vendor (nullable) |
| sales_qty | NUMERIC | Units sold |
| sales_dollars | NUMERIC | Revenue |
| sales_price | NUMERIC | Unit selling price |
| excise_tax | NUMERIC | Tax component |

### `fact_purchases`
| Column | Type | Description |
|--------|------|-------------|
| purchase_id | BIGSERIAL | Primary key |
| receiving_date_key | INT | FK -> dim_date (goods received) |
| approval_date_key | INT | FK -> dim_date (PO approved) |
| store_key | INT | FK -> dim_store |
| product_key | INT | FK -> dim_product |
| vendor_key | INT | FK -> dim_vendor |
| purchase_qty | NUMERIC | Units received |
| purchase_dollars | NUMERIC | Total purchase value |
| purchase_price | NUMERIC | Unit cost |
| freight_cost | NUMERIC | Shipping cost from invoice |
| lead_time_days | INT | ReceivingDate minus ApprovalDate |

---

## KPI Definitions

| KPI | Formula | View |
|-----|---------|------|
| Inventory Turnover | total_cogs / avg_inventory_value | vw_inventory_turnover |
| DSI | 365 / inventory_turnover | vw_inventory_turnover |
| Stockout Rate % | stockout_skus / total_skus x 100 | vw_stockout_rate |
| Overstock % | overstock_skus / total_skus x 100 | vw_overstock |
| Reorder Point | avg_daily_sales x lead_time_days + safety_stock | vw_overstock |
| Suggested Order Qty | reorder_point x 2 minus ending_qty | vw_reorder_recommendations |
