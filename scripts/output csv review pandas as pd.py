import pandas as pd
import os

input_path = r"C:\Users\User\Desktop\Analytics\04_Inventory_Performance_Analysis\data\raw\SalesFINAL12312016.csv"
output_dir = r"C:\Users\User\Desktop\Analytics\04_Inventory_Performance_Analysis\data\raw_review"

# 若 raw_review 資料夾不存在，自動建立
os.makedirs(output_dir, exist_ok=True)

# 只讀取前 100 行（不含 header）
df = pd.read_csv(input_path, nrows=100)

# 輸出檔名：原檔名 + _review_100rows.csv
output_filename = os.path.splitext(os.path.basename(input_path))[0] + "_review_100rows.csv"
output_path = os.path.join(output_dir, output_filename)

df.to_csv(output_path, index=False, encoding="utf-8-sig")

print(f"✅ 完成！輸出路徑：{output_path}")
print(f"📊 Shape: {df.shape}")