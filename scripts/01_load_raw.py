"""
01_load_raw.py
Project : 04 Inventory Performance Analysis
Purpose : Load all raw CSV files into PostgreSQL raw schema
Run     : python scripts/01_load_raw.py
Requires: pip install pandas sqlalchemy psycopg2-binary python-dotenv
"""

import os
import re
import pandas as pd
from sqlalchemy import create_engine, text
from dotenv import load_dotenv

# ------------------------------------------------------------------
# Config
# ------------------------------------------------------------------
load_dotenv()  # reads .env file in project root (never commit .env!)

DB_URL = os.getenv(
    "DATABASE_URL",
    "postgresql://postgres:password@localhost:5432/inventory_db"  # fallback
)

# Map: raw table name → CSV filename (place full CSVs in data/raw/)
FILE_MAP = {
    "raw_sales":              "C:/Program Files/PostgreSQL/18/data/pwc_stock/SalesFINAL12312016.csv",
    "raw_purchases":          "C:/Program Files/PostgreSQL/18/data/pwc_stock/PurchasesFINAL12312016.csv",
    "raw_beg_inventory":      "C:/Program Files/PostgreSQL/18/data/pwc_stock/BegInvFINAL12312016.csv",
    "raw_end_inventory":      "C:/Program Files/PostgreSQL/18/data/pwc_stock/EndInvFINAL12312016.csv",
    "raw_invoice_purchases":  "C:/Program Files/PostgreSQL/18/data/pwc_stock/InvoicePurchases12312016.csv",
    "raw_purchase_prices":    "C:/Program Files/PostgreSQL/18/data/pwc_stock/2017PurchasePricesDec.csv",
}

RAW_DATA_DIR = os.path.join(os.path.dirname(__file__), "..", "data", "raw")
SCHEMA = "raw"


# ------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------
def to_snake_case(col: str) -> str:
    """Normalise column names to snake_case."""
    col = col.strip()
    col = re.sub(r"([A-Z]+)([A-Z][a-z])", r"\1_\2", col)  # ABCDef → ABC_Def
    col = re.sub(r"([a-z0-9])([A-Z])", r"\1_\2", col)       # camelCase → camel_Case
    col = re.sub(r"[\s\-/]+", "_", col)                      # spaces/hyphens/slashes
    col = re.sub(r"[^a-zA-Z0-9_]", "", col)                  # remove other specials
    return col.lower()


def load_table(engine, table_name: str, csv_path: str) -> int:
    """Load one CSV into raw schema, return row count."""
    
    print(f"  -> Reading {table_name} from CSV...", end="", flush=True)
    
    df = pd.read_csv(
        csv_path,
        encoding="utf-8-sig",   # handles BOM (\ufeff)
        dtype=str,               # load everything as TEXT — no implicit type coercion
        keep_default_na=False,   # keep empty strings as empty, not NaN
        low_memory=False,        # 加上這行，避免型別推斷造成記憶體警告或卡頓
    )
    
    print(f" {len(df):,} rows found. Writing to database...", end="", flush=True)

    # Normalise column names
    df.columns = [to_snake_case(c) for c in df.columns]

    # Replace empty strings with None → NULL in PostgreSQL
    df = df.replace("", None)

    df.to_sql(
        name=table_name,
        con=engine,
        schema=SCHEMA,
        if_exists="replace",
        index=False,
        method="multi",
        chunksize=5000,
    )
    
    print(" Done.")
    return len(df)


def write_audit(engine, table_name: str, rows: int, source_file: str):
    with engine.connect() as conn:
        conn.execute(
            text("""
                INSERT INTO raw.load_audit (table_name, rows_loaded, source_file)
                VALUES (:t, :r, :s)
            """),
            {"t": table_name, "r": rows, "s": source_file},
        )
        conn.commit()


# ------------------------------------------------------------------
# Main
# ------------------------------------------------------------------
def main():
    engine = create_engine(DB_URL)
    print(f"\n{'='*55}")
    print(" 04_Inventory_Performance_Analysis — Raw Loader")
    print(f"{'='*55}")

    total_rows = 0
    errors = []

    for table_name, filename in FILE_MAP.items():
        csv_path = os.path.join(RAW_DATA_DIR, filename)

        if not os.path.exists(csv_path):
            msg = f"⚠️  File not found: {csv_path}"
            print(msg)
            errors.append(msg)
            continue

        try:
            rows = load_table(engine, table_name, csv_path)
            write_audit(engine, table_name, rows, filename)
            print(f"✅  {table_name:<30} {rows:>8,} rows")
            total_rows += rows
        except Exception as e:
            msg = f"❌  {table_name}: {e}"
            print(msg)
            errors.append(msg)

    print(f"{'─'*55}")
    print(f"   Total rows loaded : {total_rows:,}")
    if errors:
        print(f"   Errors           : {len(errors)}")
        for err in errors:
            print(f"     {err}")
    print(f"{'='*55}\n")


if __name__ == "__main__":
    main()
