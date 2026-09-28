from pathlib import Path

import pandas as pd

from db import get_engine

ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "data" / "processed"

TABLES = [
    "dim_date",
    "dim_state",
    "dim_maker",
    "dim_fuel",
    "dim_vehicle_category",
    "fact_registrations",
    "fact_maker_registrations",
]


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    engine = get_engine()
    for table in TABLES:
        df = pd.read_sql_table(table, engine)
        df.to_csv(OUT_DIR / f"{table}.csv", index=False)
        print(f"{table:<26} {len(df):>7,} rows -> data/processed/{table}.csv")


if __name__ == "__main__":
    main()
