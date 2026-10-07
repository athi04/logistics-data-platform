import pandas as pd
from pathlib import Path


DATA_DIR = Path("data")


for file_path in sorted(DATA_DIR.glob("*.csv")):

    print("\n" + "=" * 80)
    print(f"FILE: {file_path.name}")
    print("=" * 80)

    df = pd.read_csv(file_path)

    print(f"Rows: {len(df):,}")
    print(f"Columns: {len(df.columns)}")

    print("\nColumns:")
    print(df.dtypes)

    print("\nMissing values:")
    print(df.isna().sum()) 