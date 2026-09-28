# India EV Adoption & Market Share Analysis

<!-- one-line summary -->

![Python](https://img.shields.io/badge/Python-3.13-3776AB?logo=python&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-15-4169E1?logo=postgresql&logoColor=white)
![pandas](https://img.shields.io/badge/pandas-3.0-150458?logo=pandas&logoColor=white)
![Power BI](https://img.shields.io/badge/Power%20BI-Desktop-F2C811?logo=powerbi&logoColor=black)
![Tableau](https://img.shields.io/badge/Tableau-Public-E97627?logo=tableau&logoColor=white)

## Business problem

<!-- your wording: consultant for a two-wheeler EV brand planning to expand. How fast is adoption growing,
in which states, who holds share where, and which states to prioritise next? -->

## Data sources

| Data | Source | Coverage |
|---|---|---|
| Vehicle registrations | [Vahan dashboard](https://vahan.parivahan.gov.in/vahan4dashboard/vahan/view/reportview.xhtml), downloaded manually | Jan 2023 - Aug 2026, 36 states/UTs, monthly |
| State population | Population Projections for India and States 2011-2036 (National Commission on Population, MoHFW), Table 14 | Projection as on 1 Oct 2025 |
| State regions | Grouped by MHA Zonal Councils; Northeast = the eight North Eastern Council states | 36 states/UTs |

How to download the Vahan files, with exact filter settings: [`data/raw/README.md`](data/raw/README.md).

Definitions:
- **Two-wheeler (2W)**: Vahan vehicle categories TWO WHEELER(NT), TWO WHEELER(T), TWO WHEELER (Invalid Carriage)
- **Electric two-wheeler (E2W)**: 2W with fuel ELECTRIC(BOV) or PURE EV (Vahan uses both labels)
- **EV penetration %**: E2W registrations / all 2W registrations
- **Financial year**: April to March (FY2025-26 = Apr 2025 - Mar 2026)

## Data dictionary

| Table | Grain | Columns |
|---|---|---|
| `fact_registrations` | state x month x fuel group | `date_key`, `state_key`, `fuel_key`, `vehicle_category_key`, `registrations` |
| `fact_maker_registrations` | state x month x maker (E2W only) | `date_key`, `state_key`, `maker_key`, `fuel_key`, `vehicle_category_key`, `registrations` |
| `dim_date` | month | `date_key` (YYYYMM), `month_start`, `calendar_year`, `month_no`, `month_name`, `fy`, `fy_start_year`, `fy_quarter`, `fy_month_no`, `is_festive` (Sep-Nov) |
| `dim_state` | state | `state_key`, `state_name`, `vahan_name`, `region`, `population`, `has_maker_data` |
| `dim_maker` | Vahan maker name | `maker_key`, `maker_raw`, `maker_name` (standardised), `parent_group` |
| `dim_fuel` | fuel group | `fuel_key`, `fuel_group` (Electric / Non-electric), `is_electric`, `vahan_fuels` |
| `dim_vehicle_category` | category | `vehicle_category_key`, `category_name`, `vahan_categories` |

`fact_maker_registrations` holds state-level rows for states with maker data plus a "Rest of India" row
(national total minus those states), so it always sums to the national figure.

## Data model

```mermaid
erDiagram
    dim_date ||--o{ fact_registrations : date_key
    dim_state ||--o{ fact_registrations : state_key
    dim_fuel ||--o{ fact_registrations : fuel_key
    dim_vehicle_category ||--o{ fact_registrations : vehicle_category_key
    dim_date ||--o{ fact_maker_registrations : date_key
    dim_state ||--o{ fact_maker_registrations : state_key
    dim_maker ||--o{ fact_maker_registrations : maker_key
    dim_fuel ||--o{ fact_maker_registrations : fuel_key
    dim_vehicle_category ||--o{ fact_maker_registrations : vehicle_category_key
```

Two fact tables because Vahan only exports two-dimensional pivots (state x month, or maker x month),
so each fact keeps the grain its source reports actually have.

## Methodology

1. **Collect**: Vahan "Month Wise" reports per calendar year (FY is derived from the month in code).
2. **Combine** (`src/combine_raw.py`): parses multi-row headers, converts Indian-format numbers
   (`25,11,130`), reshapes wide months to long, checks each row against Vahan's TOTAL column, maps state
   names, and cross-checks reports against each other to catch files downloaded with the wrong filters.
3. **Load** (`src/load_to_postgres.py`): builds the star schema, drops the incomplete latest month,
   derives non-electric = all 2W - electric, and Rest of India = national - covered states.
4. **Validate** (`sql/02_validation.sql`): totals reconcile to the raw reports per state and month,
   maker totals match state totals, no orphan keys, negatives or duplicate grain rows. All 9 checks pass.
5. **Analyse** (`sql/03_analysis.sql`): 12 business questions with CTEs and window functions.
6. **Explore** (`notebooks/01_eda.ipynb`) and **visualise** in Power BI and Tableau from `data/processed/*.csv`.

## Highlight queries

FYTD registrations with YoY % for the same months of the previous FY:
```sql
fytd AS (
    SELECT *, SUM(e2w) OVER (PARTITION BY fy ORDER BY fy_month_no) AS fytd_e2w
    FROM full_start
)
SELECT cur.fy, cur.month_start, cur.fytd_e2w, prev.fytd_e2w AS py_fytd_e2w,
       ROUND(100.0 * (cur.fytd_e2w - prev.fytd_e2w) / NULLIF(prev.fytd_e2w, 0), 1) AS fytd_yoy_pct
FROM fytd cur
LEFT JOIN fytd prev
       ON prev.fy_start_year = cur.fy_start_year - 1
      AND prev.fy_month_no = cur.fy_month_no;
```

Market concentration (HHI) per state:
```sql
SELECT state_name, ROUND(SUM(share_pct * share_pct)) AS hhi
FROM shares
GROUP BY state_name;
```

Makers gaining or losing share, last 12 months vs the 12 before, and the state prioritisation
scorecard with a weight-sensitivity test: see Q9 and Q12 in [`sql/03_analysis.sql`](sql/03_analysis.sql).

## Screenshots

![National trend](images/01_national_trend.png)
![Penetration by state](images/03_state_penetration.png)
![Maker share](images/04_maker_share.png)
![State size vs growth](images/05_state_2x2.png)

<!-- add Power BI / Tableau screenshots and the walkthrough GIF -->

## Key insights

<!-- your wording; supporting numbers are in reports/insights_summary.md -->

## Recommendations

<!-- your wording -->

## Challenges I faced

<!-- your wording. Facts to draw on:
- Vahan's Excel export failed intermittently (HTTP 503); the old dashboard is being replaced by a new portal with a CAPTCHA
- Export titles don't record filters; 28 files were first downloaded without the 2W/EV filters and were caught by cross-report checks
- "Financial Year" with Month Wise returned the same Jan-Dec table, so calendar years were downloaded and FY derived in code
- Electric vehicles appear under two fuel labels (ELECTRIC(BOV) and PURE EV)
- Maker names are legal entities with renames and spelling variants (e.g. Ampere Vehicles -> Greaves Electric Mobility)
- The first FY in the data is partial, which broke FYTD YoY until partial FYs were excluded -->

## Links

- Tableau Public: <!-- link -->
- NovyPro: <!-- link -->
- Walkthrough video: <!-- link -->

## How to reproduce

Requires Python 3.11+ and PostgreSQL 15.

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

# create the database and user (once), then fill in DB_PASSWORD
psql postgres -c "CREATE USER ev_user WITH PASSWORD '<password>';"
psql postgres -c "CREATE DATABASE india_ev OWNER ev_user;"
cp .env.example .env

python src/check_connection.py      # prints "connected"
python src/combine_raw.py           # data/raw/*.xlsx -> data/interim/*.csv, profile and filter checks
python src/load_to_postgres.py      # builds and loads the star schema
psql -d india_ev -U ev_user -f sql/02_validation.sql
psql -d india_ev -U ev_user -f sql/03_analysis.sql
python src/export_for_bi.py         # data/processed/*.csv for Power BI and Tableau
jupyter lab notebooks/01_eda.ipynb
```

Power BI and Tableau build steps: [`powerbi/POWERBI_GUIDE.md`](powerbi/POWERBI_GUIDE.md),
[`tableau/TABLEAU_GUIDE.md`](tableau/TABLEAU_GUIDE.md).

## Project structure

```
data/raw/          Vahan exports (see data/raw/README.md)
data/reference/    state population, state-to-region mapping, maker-name mapping
data/processed/    star-schema tables as CSV for Power BI / Tableau
sql/               schema, validation and analysis queries
notebooks/         exploratory analysis
src/               combine, load, export and connection scripts
powerbi/           build guide, theme, report and PDF export
tableau/           build guide, link and screenshots
images/            charts and dashboard screenshots
reports/           insights summary
```

## What I'd do next

<!-- your wording -->
