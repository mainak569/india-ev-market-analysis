import re
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
RAW_DIR = ROOT / "data" / "raw"
REFERENCE_DIR = ROOT / "data" / "reference"
INTERIM_DIR = ROOT / "data" / "interim"

MONTHS = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]

# report letter -> (output file, name of the row dimension)
REPORTS = {
    "B": ("all2w_state_month.csv", "vahan_state"),
    "C": ("e2w_state_month.csv", "vahan_state"),
    "D": ("e2w_maker_month_india.csv", "maker_raw"),
    "E": ("all2w_fuel_month_india.csv", "fuel"),
    "A": ("e2w_maker_month_state.csv", "maker_raw"),
}

FILE_NAME = re.compile(r"^(?P<report>[A-E])_[a-z0-9]+_[a-z]+_(?P<scope>[a-z_]+?_)?CY(?P<year>\d{4})\.xlsx$")


def to_int(text):
    return int(str(text).replace(",", "").strip())


def read_report(path):
    """Read one Vahan 'Month Wise' export and return it in long format."""
    sheet = pd.read_excel(path, header=None, dtype=str).fillna("")
    title = sheet.iat[0, 0].strip()

    header_row = sheet.index[sheet.apply(lambda r: "JAN" in r.values, axis=1)][0]
    header = [str(v).strip() for v in sheet.iloc[header_row]]
    month_cols = {i: MONTHS.index(v) + 1 for i, v in enumerate(header) if v in MONTHS}
    total_col = len(header) - 1

    rows = sheet.iloc[header_row + 1:]
    rows = rows[rows[0].str.strip().str.isdigit()]

    records = []
    for _, row in rows.iterrows():
        name = " ".join(row[1].split())
        values = {m: to_int(row[i]) for i, m in month_cols.items() if row[i].strip() != ""}
        # Vahan's own TOTAL column must equal the sum of the month columns
        if sum(values.values()) != to_int(row[total_col]):
            raise ValueError(f"{path.name}: TOTAL mismatch for {name}")
        for month, count in values.items():
            records.append((name, month, count))

    long = pd.DataFrame(records, columns=["name", "month", "registrations"])
    return title, long


def combine():
    INTERIM_DIR.mkdir(exist_ok=True)
    states = pd.read_csv(REFERENCE_DIR / "state_region.csv")
    vahan_to_state = {v.upper(): s for s, v in zip(states["state"], states["vahan_name"])}
    slug_to_state = {s.lower().replace(" ", "_"): s for s in states["state"]}

    frames = {letter: [] for letter in REPORTS}
    for path in sorted(RAW_DIR.glob("*.xlsx")):
        match = FILE_NAME.match(path.name)
        if not match:
            print(f"skipping {path.name}: name doesn't follow the convention")
            continue
        letter, year = match["report"], int(match["year"])
        title, long = read_report(path)
        if f"({year})" not in title:
            raise ValueError(f"{path.name}: title '{title}' doesn't match year {year}")

        long.insert(0, "year", year)
        if letter == "A":
            long.insert(0, "state", slug_to_state[match["scope"].rstrip("_")])
        frames[letter].append(long)

    combined = {}
    for letter, parts in frames.items():
        if not parts:
            continue
        out_name, dim = REPORTS[letter]
        df = pd.concat(parts, ignore_index=True).rename(columns={"name": dim})
        if dim == "vahan_state":
            df.insert(0, "state", df[dim].map(vahan_to_state))
            unmapped = df.loc[df["state"].isna(), dim].unique()
            if len(unmapped):
                raise ValueError(f"unmapped Vahan state names: {list(unmapped)}")
            df = df.drop(columns=dim)
        df.to_csv(INTERIM_DIR / out_name, index=False)
        combined[letter] = df
    return combined


def profile(combined):
    for letter, df in combined.items():
        periods = df["year"].astype(str) + "-" + df["month"].astype(str).str.zfill(2)
        print(f"\nReport {letter} -> {REPORTS[letter][0]}")
        print(f"  rows: {len(df):,}   months: {periods.min()} to {periods.max()} ({periods.nunique()})")
        if "state" in df:
            print(f"  states: {df['state'].nunique()}")
        if "maker_raw" in df:
            print(f"  makers: {df['maker_raw'].nunique()}")
        print(f"  total registrations: {df['registrations'].sum():,}")
        print(f"  nulls: {int(df.isna().sum().sum())}   duplicate rows: {int(df.duplicated().sum())}")
        print(f"  zero-count rows: {int((df['registrations'] == 0).sum())}")


if __name__ == "__main__":
    profile(combine())
