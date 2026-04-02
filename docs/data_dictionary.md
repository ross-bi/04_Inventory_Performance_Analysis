# Data Dictionary

## Staging Tables

### stg_beg_inventory
| Column | Type | Source | Description |
|--------|------|--------|-------------|
| inventory_id | VARCHAR | BegInvFINAL12312016 | Composite key `{Store}_{City}_{Brand}` |
| store_id | INT | BegInvFINAL12312016 | Store number |
| city | VARCHAR | BegInvFINAL12312016 | Store city name |
| brand_id | INT | BegInvFINAL12312016 | Brand/product code |
| description | VARCHAR | BegInvFINAL12312016 | Product description |
| size | VARCHAR | BegInvFINAL12312016 | Package size (e.g. 750mL) |
| on_hand | INT | BegInvFINAL12312016 | Units on hand at period start |
| price | NUMERIC(10,2) | BegInvFINAL12312016 | Retail selling price |
| start_date | DATE | BegInvFINAL12312016 | Period start date (2016-01-01) |

### stg_end_inventory
| Column | Type | Source | Description |
|--------|------|--------|-------------|
| inventory_id | VARCHAR | EndInvFINAL12312016 | Composite key |
| store_id | INT | EndInvFINAL12312016 | Store number |
| city | VARCHAR | EndInvFINAL12312016 | Store city name |
| brand_id | INT | EndInvFINAL12312016 | Brand/product code |
| description | VARCHAR | EndInvFINAL12312016 | Product description |
| size | VARCHAR | EndInvFINAL12312016 | Package size |
| on_hand | INT | EndInvFINAL12312016 | Units on hand at period end |
| price | NUMERIC(10,2) | EndInvFINAL12312016 | Retail selling price |
| end_date | DATE | EndInvFINAL12312016 | Period end date (2016-12-31) |

### stg_sales
| Column | Type | Source | Description |
|--------|------|--------|-------------|
| inventory_id | VARCHAR | SalesFINAL12312016 | SKU + Store identifier |
| store_id | INT | SalesFINAL12312016 | Store number |
| brand_id | INT | SalesFINAL12312016 | Brand/product code |
| description | VARCHAR | SalesFINAL12312016 | Product description |
| size | VARCHAR | SalesFINAL12312016 | Package size |
| sales_quantity | INT | SalesFINAL12312016 | Units sold |
| sales_dollars | NUMERIC(12,2) | SalesFINAL12312016 | Revenue |
| sales_price | NUMERIC(10,2) | SalesFINAL12312016 | Actual selling price |
| sales_date | DATE | SalesFINAL12312016 | Transaction date |
| volume | INT | SalesFINAL12312016 | Volume (mL) |
| classification | INT | SalesFINAL12312016 | Product classification (1=spirits, 2=wine…) |
| excise_tax | NUMERIC(8,2) | SalesFINAL12312016 | Excise tax per transaction |
| vendor_no | INT | SalesFINAL12312016 | Vendor identifier |
| vendor_name | VARCHAR | SalesFINAL12312016 | Vendor name |

### stg_purchases
| Column | Type | Source | Description |
|--------|------|--------|-------------|
| inventory_id | VARCHAR | PurchasesFINAL12312016 | SKU + Store identifier |
| store_id | INT | PurchasesFINAL12312016 | Store number |
| brand_id | INT | PurchasesFINAL12312016 | Brand/product code |
| description | VARCHAR | PurchasesFINAL12312016 | Product description |
| size | VARCHAR | PurchasesFINAL12312016 | Package size |
| vendor_number | INT | PurchasesFINAL12312016 | Vendor identifier |
| vendor_name | VARCHAR | PurchasesFINAL12312016 | Vendor name |
| po_number | INT | PurchasesFINAL12312016 | Purchase Order number |
| po_date | DATE | PurchasesFINAL12312016 | PO creation date |
| receiving_date | DATE | PurchasesFINAL12312016 | Date goods received |
| invoice_date | DATE | PurchasesFINAL12312016 | Invoice date |
| pay_date | DATE | PurchasesFINAL12312016 | Payment date |
| purchase_price | NUMERIC(10,2) | PurchasesFINAL12312016 | Unit cost |
| quantity | INT | PurchasesFINAL12312016 | Units ordered |
| dollars | NUMERIC(12,2) | PurchasesFINAL12312016 | Total purchase amount |
| classification | INT | PurchasesFINAL12312016 | Product classification |

### stg_invoice_purchases
| Column | Type | Source | Description |
|--------|------|--------|-------------|
| vendor_number | INT | InvoicePurchases12312016 | Vendor identifier |
| vendor_name | VARCHAR | InvoicePurchases12312016 | Vendor name |
| invoice_date | DATE | InvoicePurchases12312016 | Invoice date |
| po_number | INT | InvoicePurchases12312016 | Purchase Order number |
| po_date | DATE | InvoicePurchases12312016 | PO creation date |
| pay_date | DATE | InvoicePurchases12312016 | Payment date |
| quantity | INT | InvoicePurchases12312016 | Total units on invoice |
| dollars | NUMERIC(12,2) | InvoicePurchases12312016 | Invoice total |
| freight | NUMERIC(10,2) | InvoicePurchases12312016 | Freight cost |
| approval | VARCHAR | InvoicePurchases12312016 | Approval status |

### stg_purchase_prices
| Column | Type | Source | Description |
|--------|------|--------|-------------|
| brand_id | INT | 2017PurchasePricesDec | Brand/product code |
| description | VARCHAR | 2017PurchasePricesDec | Product description |
| price | NUMERIC(10,2) | 2017PurchasePricesDec | Retail price |
| size | VARCHAR | 2017PurchasePricesDec | Package size |
| volume | INT | 2017PurchasePricesDec | Volume (mL) |
| classification | INT | 2017PurchasePricesDec | Product classification |
| purchase_price | NUMERIC(10,2) | 2017PurchasePricesDec | Unit cost (latest reference) |
| vendor_number | INT | 2017PurchasePricesDec | Vendor identifier |
| vendor_name | VARCHAR | 2017PurchasePricesDec | Vendor name |

---

## Dimension Tables

### dim_product
| Column | Description |
|--------|-------------|
| product_key (PK) | Surrogate key |
| brand_id | Natural key |
| description | Product name |
| size | Package size |
| volume_ml | Numeric volume |
| classification | 1=Spirits, 2=Wine, 3=Beer, etc. |
| classification_name | Human-readable category |
| retail_price | Latest retail price |
| purchase_price | Latest cost price |
| gross_margin_pct | (retail - cost) / retail |
| vendor_number | Primary vendor |

### dim_store
| Column | Description |
|--------|-------------|
| store_key (PK) | Surrogate key |
| store_id | Natural key |
| city | Store city |

### dim_vendor
| Column | Description |
|--------|-------------|
| vendor_key (PK) | Surrogate key |
| vendor_number | Natural key |
| vendor_name | Vendor name |
| avg_lead_time_days | Computed avg lead time |

### dim_date
| Column | Description |
|--------|-------------|
| date_key (PK) | YYYYMMDD integer |
| full_date | DATE |
| year | 2016 |
| quarter | 1–4 |
| month | 1–12 |
| month_name | Jan–Dec |
| week | ISO week number |
| day_of_week | 1–7 |
| is_weekend | BOOLEAN |

---

## Fact Tables

### fact_sales
| Column | Description |
|--------|-------------|
| sale_key (PK) | Surrogate key |
| date_key (FK) | → dim_date |
| product_key (FK) | → dim_product |
| store_key (FK) | → dim_store |
| vendor_key (FK) | → dim_vendor |
| sales_quantity | Units sold |
| sales_dollars | Revenue |
| sales_price | Selling price |
| excise_tax | Excise tax |
| cogs | purchase_price × sales_quantity (derived) |
| gross_profit | sales_dollars − cogs |

### fact_purchases
| Column | Description |
|--------|-------------|
| purchase_key (PK) | Surrogate key |
| po_date_key (FK) | → dim_date (PO date) |
| receiving_date_key (FK) | → dim_date (received) |
| product_key (FK) | → dim_product |
| store_key (FK) | → dim_store |
| vendor_key (FK) | → dim_vendor |
| po_number | PO reference |
| quantity | Units ordered |
| dollars | Purchase cost |
| lead_time_days | receiving_date − po_date |

### fact_inventory_snapshot
| Column | Description |
|--------|-------------|
| snapshot_key (PK) | Surrogate key |
| snapshot_date_key (FK) | → dim_date |
| product_key (FK) | → dim_product |
| store_key (FK) | → dim_store |
| on_hand_qty | Units on hand |
| on_hand_cost | on_hand_qty × purchase_price |
| on_hand_retail | on_hand_qty × retail_price |
| snapshot_type | 'BEG' or 'END' |
