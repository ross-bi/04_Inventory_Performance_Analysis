# 04 Inventory Performance Analysis

> **PwC × Kaggle — Inventory Analysis Case Study**  
> 工具：VSCode · PostgreSQL · Power BI · Python

---

## 📌 專案目標

分析一家酒類零售商（2016年）的庫存績效，涵蓋以下五大 KPI：

| KPI | 說明 |
|---|---|
| **Inventory Turnover** | 庫存周轉率：衡量庫存多快被銷售出去 |
| **Days Sales of Inventory (DSI)** | 庫存銷售天數：平均庫存可支撐幾天的銷售 |
| **Stockout Rate** | 缺貨率：期末庫存為零的商品比例 |
| **Overstock %** | 呆滯庫存比例：期末庫存過剩的商品比例 |
| **Reorder Point** | 補貨觸發點：計算合理的補貨時機 |

---

## 🗂️ 資料來源

**Kaggle：** [Inventory Analysis Case Study (PwC)](https://www.kaggle.com/bhanupratapbiswas/inventory-analysis-case-study)

| 原始檔案 | 說明 |
|---|---|
| `SalesFINAL12312016.csv` | 銷售明細（2016 全年） |
| `PurchasesFINAL12312016.csv` | 採購明細 |
| `BegInvFINAL12312016.csv` | 期初庫存（2016-01-01） |
| `EndInvFINAL12312016.csv` | 期末庫存（2016-12-31） |
| `InvoicePurchases12312016.csv` | 採購發票 |
| `2017PurchasePricesDec.csv` | 採購單價參考 |

> 原始 CSV 放於 `data/raw/`（已列入 `.gitignore`，不上傳至 GitHub）  
> 100 行預覽版本放於 `data/raw_review/`

---

## 🏗️ 架構設計

### ELT Pipeline（三層架構）

```
CSV Files
    │
    ▼
[raw schema]      ← 直接載入，all TEXT，保持原始
    │
    ▼
[staging schema]  ← 型別轉換、snake_case、NULL 處理、資料核對
    │
    ▼
[marts schema]    ← 星型架構 Dim/Fact + KPI Views（供 Power BI 直連）
```

### 星型架構（Star Schema）

```


```

| 資料表 | 類型 | 說明 |
|---|---|---|
| `fact_inventory_movement` | Fact | 核心事實表，整合銷售、採購、庫存 |
| `dim_product` | Dimension | 商品資訊（品牌、規格、分類） |
| `dim_store` | Dimension | 門市資訊 |
| `dim_vendor` | Dimension | 供應商資訊 |
| `dim_date` | Dimension | 日期維度（年、月、季、週） |

---

## 🚀 如何執行專案

### 前置準備

```bash
# 1. Clone 專案
git clone https://github.com/ross-bi/04_Inventory_Performance_Analysis.git
cd 04_Inventory_Performance_Analysis

# 2. 建立並啟動虛擬環境
python -m venv 04_env
.\04_env\Scripts\activate   # Windows PowerShell

# 3. 安裝套件
pip install pandas sqlalchemy psycopg2-binary python-dotenv

# 4. 設定資料庫連線
cp .env.example .env
# 用 VSCode 打開 .env，填入你的 PostgreSQL 密碼
```

### 執行順序

```bash
# Step 1：建立資料庫 Schema
# 在 pgAdmin / DBeaver 執行：
sql/00_schema_setup.sql

# Step 2：載入原始 CSV → raw schema
# 把完整 CSV 放入 data/raw/ 資料夾後執行：
python -u scripts/01_load_raw.py

# Step 3：Staging 清洗（即將新增）
# sql/staging/stg_*.sql

# Step 4：Mart 層 + KPI Views（即將新增）
# sql/marts/*.sql
```

---

## 📁 專案結構

```
04_Inventory_Performance_Analysis/
├── data/
│   ├── raw/                    ← 完整 CSV（gitignored，不上傳）
│   └── raw_review/             ← 100 行預覽版本
├── scripts/
│   └── 01_load_raw.py          ← Python ELT Loader
├── sql/
│   ├── 00_schema_setup.sql     ← Schema + Raw Table 建立
│   ├── staging/                ← 資料清洗 Views
│   ├── audit/                  ← 庫存核對 SQL
│   └── marts/                  ← Dim/Fact + KPI Views
├── powerbi/
│   └── Inventory_Performance.pbix
├── log.ipynb                   ← 開發日誌與踩坑紀錄
├── .env.example                ← 資料庫連線範本
└── README.md
```

---

## 📊 Power BI 儀表板



---

## 📝 開發日誌

詳細的踩坑紀錄與學習筆記請見 [`log.ipynb`](./log.ipynb)

---

## 👤 作者

**Ross** — BI Analyst Portfolio Project  
Data Source: PwC × Kaggle Inventory Analysis Case Study
