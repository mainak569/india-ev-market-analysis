from pathlib import Path

import pandas as pd
from sqlalchemy import text

from db import get_engine

ROOT = Path(__file__).resolve().parents[1]
INTERIM_DIR = ROOT / "data" / "interim"
REFERENCE_DIR = ROOT / "data" / "reference"

# Files were downloaded on 28 Sep 2026, so September 2026 is only partly reported
LAST_COMPLETE_MONTH = (2026, 8)
REST_OF_INDIA = "Rest of India"
MONTH_NAMES = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]


def read_interim(name):
    path = INTERIM_DIR / name
    return pd.read_csv(path) if path.exists() else None


def drop_incomplete_months(df):
    period = df["year"] * 100 + df["month"]
    return df[period <= LAST_COMPLETE_MONTH[0] * 100 + LAST_COMPLETE_MONTH[1]].copy()


def add_date_key(df):
    df["date_key"] = df["year"] * 100 + df["month"]
    return df


def build_dim_date(frames):
    keys = pd.concat([f["year"] * 100 + f["month"] for f in frames])
    months = pd.date_range(
        f"{keys.min() // 100}-{keys.min() % 100:02d}-01",
        f"{keys.max() // 100}-{keys.max() % 100:02d}-01",
        freq="MS",
    )
    dim = pd.DataFrame({"month_start": months})
    dim["calendar_year"] = dim["month_start"].dt.year
    dim["month_no"] = dim["month_start"].dt.month
    dim["date_key"] = dim["calendar_year"] * 100 + dim["month_no"]
    dim["month_name"] = dim["month_no"].map(lambda m: MONTH_NAMES[m - 1])
    # Indian FY runs April to March: Jan-Mar belong to the FY that started the previous April
    dim["fy_start_year"] = dim["calendar_year"].where(dim["month_no"] >= 4, dim["calendar_year"] - 1)
    dim["fy"] = "FY" + dim["fy_start_year"].astype(str) + "-" + ((dim["fy_start_year"] + 1) % 100).astype(str).str.zfill(2)
    dim["fy_month_no"] = (dim["month_no"] - 4) % 12 + 1
    dim["fy_quarter"] = "Q" + ((dim["fy_month_no"] - 1) // 3 + 1).astype(str)
    dim["is_festive"] = dim["month_no"].isin([9, 10, 11])
    dim["month_start"] = dim["month_start"].dt.date
    return dim[["date_key", "month_start", "calendar_year", "month_no", "month_name",
                "fy", "fy_start_year", "fy_quarter", "fy_month_no", "is_festive"]]


def build_dim_state(maker_states, include_rest):
    regions = pd.read_csv(REFERENCE_DIR / "state_region.csv")
    population = pd.read_csv(REFERENCE_DIR / "state_population.csv")[["state", "population"]]
    dim = regions.merge(population, on="state", how="left")
    dim = dim.rename(columns={"state": "state_name"})
    dim["has_maker_data"] = dim["state_name"].isin(maker_states)
    if include_rest:
        rest = pd.DataFrame([{"state_name": REST_OF_INDIA, "vahan_name": None, "region": REST_OF_INDIA,
                              "population": None, "has_maker_data": True}])
        dim = pd.concat([dim, rest], ignore_index=True)
    dim.insert(0, "state_key", range(1, len(dim) + 1))
    return dim[["state_key", "state_name", "vahan_name", "region", "population", "has_maker_data"]]


def build_dim_maker(maker_names):
    mapping = pd.read_csv(REFERENCE_DIR / "maker_mapping.csv")
    missing = sorted(set(maker_names) - set(mapping["maker_raw"]))
    if missing:
        raise ValueError(f"{len(missing)} makers missing from maker_mapping.csv, e.g. {missing[:5]}")
    dim = mapping[mapping["maker_raw"].isin(maker_names)].reset_index(drop=True)
    dim.insert(0, "maker_key", range(1, len(dim) + 1))
    return dim[["maker_key", "maker_raw", "maker_name", "parent_group"]]


def build_fact_registrations(all2w, e2w, state_keys):
    merged = all2w.merge(e2w, on=["state", "year", "month"], how="left", suffixes=("_all", "_ev"))
    merged["registrations_ev"] = merged["registrations_ev"].fillna(0).astype(int)
    merged["registrations_other"] = merged["registrations_all"] - merged["registrations_ev"]
    if (merged["registrations_other"] < 0).any():
        raise ValueError("electric registrations exceed all two-wheeler registrations for some state-months")

    electric = merged[["state", "year", "month", "registrations_ev"]].rename(columns={"registrations_ev": "registrations"})
    electric["fuel_key"] = 1
    other = merged[["state", "year", "month", "registrations_other"]].rename(columns={"registrations_other": "registrations"})
    other["fuel_key"] = 2

    fact = add_date_key(pd.concat([electric, other], ignore_index=True))
    fact["state_key"] = fact["state"].map(state_keys)
    fact["vehicle_category_key"] = 1
    return fact[["date_key", "state_key", "fuel_key", "vehicle_category_key", "registrations"]]


def build_fact_maker(india, by_state, state_keys, maker_keys):
    """State-level maker rows for the states we have, plus Rest of India = national minus those states."""
    keys = ["maker_raw", "year", "month"]
    parts = []
    if by_state is not None:
        parts.append(by_state)
        covered = by_state.groupby(keys, as_index=False)["registrations"].sum()
        rest = india.merge(covered, on=keys, how="left", suffixes=("", "_covered"))
        rest["registrations"] = rest["registrations"] - rest["registrations_covered"].fillna(0).astype(int)
    else:
        rest = india.copy()
    if (rest["registrations"] < 0).any():
        raise ValueError("state-level maker totals exceed the national totals for some maker-months")
    rest["state"] = REST_OF_INDIA
    parts.append(rest[["state"] + keys + ["registrations"]])

    fact = add_date_key(pd.concat(parts, ignore_index=True))
    fact = fact[fact["registrations"] > 0]
    fact["state_key"] = fact["state"].map(state_keys)
    fact["maker_key"] = fact["maker_raw"].map(maker_keys)
    fact["fuel_key"] = 1
    fact["vehicle_category_key"] = 1
    return fact[["date_key", "state_key", "maker_key", "fuel_key", "vehicle_category_key", "registrations"]]


def main():
    all2w = read_interim("all2w_state_month.csv")
    e2w = read_interim("e2w_state_month.csv")
    maker_india = read_interim("e2w_maker_month_india.csv")
    maker_state = read_interim("e2w_maker_month_state.csv")
    if all2w is None or e2w is None:
        raise SystemExit("Reports B and C are required. Run src/combine_raw.py first.")

    staging = {
        "stg_all2w_state_month": all2w,
        "stg_e2w_state_month": e2w,
        "stg_e2w_maker_month_india": maker_india,
        "stg_e2w_maker_month_state": maker_state,
    }

    all2w, e2w = drop_incomplete_months(all2w), drop_incomplete_months(e2w)
    maker_india = drop_incomplete_months(maker_india) if maker_india is not None else None
    maker_state = drop_incomplete_months(maker_state) if maker_state is not None else None

    maker_states = sorted(maker_state["state"].unique()) if maker_state is not None else []
    dim_date = build_dim_date([f for f in (all2w, e2w, maker_india, maker_state) if f is not None])
    dim_state = build_dim_state(maker_states, include_rest=maker_india is not None)
    dim_fuel = pd.DataFrame({
        "fuel_key": [1, 2],
        "fuel_group": ["Electric", "Non-electric"],
        "is_electric": [True, False],
        "vahan_fuels": ["ELECTRIC(BOV), PURE EV", "All other fuels"],
    })
    dim_vehicle_category = pd.DataFrame({
        "vehicle_category_key": [1],
        "category_name": ["Two Wheeler"],
        "vahan_categories": ["TWO WHEELER(NT), TWO WHEELER(T), TWO WHEELER (Invalid Carriage)"],
    })

    state_keys = dict(zip(dim_state["state_name"], dim_state["state_key"]))
    fact_registrations = build_fact_registrations(all2w, e2w, state_keys)

    tables = {
        "dim_date": dim_date,
        "dim_state": dim_state,
        "dim_fuel": dim_fuel,
        "dim_vehicle_category": dim_vehicle_category,
    }
    if maker_india is not None:
        makers = set(maker_india["maker_raw"])
        if maker_state is not None:
            makers |= set(maker_state["maker_raw"])
        dim_maker = build_dim_maker(makers)
        maker_keys = dict(zip(dim_maker["maker_raw"], dim_maker["maker_key"]))
        tables["dim_maker"] = dim_maker
        tables["fact_maker_registrations"] = build_fact_maker(maker_india, maker_state, state_keys, maker_keys)
    tables["fact_registrations"] = fact_registrations

    engine = get_engine()
    with engine.begin() as conn:
        conn.exec_driver_sql((ROOT / "sql" / "01_schema.sql").read_text())
        for name, df in staging.items():
            if df is not None:
                df.to_sql(name, conn, if_exists="append", index=False)
        for name, df in tables.items():
            df.to_sql(name, conn, if_exists="append", index=False, method="multi", chunksize=5000)
        # keep SERIAL sequences in step with the keys inserted above
        for table, key in [("dim_state", "state_key"), ("dim_maker", "maker_key"), ("dim_fuel", "fuel_key"),
                           ("dim_vehicle_category", "vehicle_category_key")]:
            conn.execute(text(f"SELECT setval(pg_get_serial_sequence('{table}', '{key}'), "
                              f"COALESCE((SELECT MAX({key}) FROM {table}), 1))"))

    for name, df in {**staging, **tables}.items():
        if df is not None:
            print(f"{name:<28} {len(df):>8,} rows")


if __name__ == "__main__":
    main()
