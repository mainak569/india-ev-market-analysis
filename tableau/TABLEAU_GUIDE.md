# Tableau Public build guide

Tableau Public reads files only, so it uses the CSVs in `data/processed/`.
It rebuilds two dashboards: **Executive Overview** and **Competitive Landscape**.

## 1. Data source

1. **Connect > Text file** > `data/processed/fact_registrations.csv`.
2. Drag in `dim_date`, `dim_state`, `dim_fuel` and create **relationships** (the noodles, not joins):
   `date_key = date_key`, `state_key = state_key`, `fuel_key = fuel_key`.
3. Add `fact_maker_registrations.csv` as a second fact, related to `dim_date` (`date_key`),
   `dim_state` (`state_key`) and `dim_maker.csv` (`maker_key`).
   Relationships keep each fact at its own grain, like the Power BI model.
4. On `dim_date[month_start]`: **Default Properties > Fiscal Year Start > April**.

## 2. Calculated fields

| Field | Formula | DAX equivalent |
|---|---|---|
| **E2W** | `IF [is_electric] THEN [registrations] END` (on fact_registrations) | `E2W Registrations` with `CALCULATE(..., is_electric = TRUE())` |
| **Penetration %** | `SUM([E2W]) / SUM([registrations])` | `DIVIDE([E2W Registrations], [All 2W Registrations])` |
| **Latest FY Month** | `{ MAX(IF [fy] = { MAX([fy]) } THEN [fy_month_no] END) }` | implicit: the date table ends at the last data month |
| **In FYTD Window** | `[fy_month_no] <= [Latest FY Month]` | handled by `TOTALYTD` + date table |
| **FYTD E2W** | `SUM(IF [In FYTD Window] THEN [E2W] END)` | `TOTALYTD([E2W Registrations], 'Date'[Date], "03-31")` |
| **PY FYTD E2W** | `LOOKUP([FYTD E2W], -1)` (table calc, compute along `fy`) | `CALCULATE([FYTD E2W], SAMEPERIODLASTYEAR('Date'[Date]))` |
| **YoY Growth %** | `([FYTD E2W] - LOOKUP([FYTD E2W], -1)) / ABS(LOOKUP([FYTD E2W], -1))` | `DIVIDE([FYTD E2W] - [PY FYTD E2W], [PY FYTD E2W])` |
| **MoM %** | `(SUM([E2W]) - LOOKUP(SUM([E2W]), -1)) / ABS(LOOKUP(SUM([E2W]), -1))` (along `month_start`) | `DIVIDE(Curr - Prev, Prev)` with `DATEADD(..., -1, MONTH)` |
| **Market Share % (LOD)** | `SUM([registrations]) / SUM({ FIXED [fy] : SUM([registrations]) })` (on fact_maker_registrations) | `DIVIDE([Maker E2W], CALCULATE([Maker E2W], ALL(dim_maker)))` |
| **Market Share % (table calc)** | Quick table calculation **Percent of Total**, compute using `maker_name` | same as above |

`FYTD E2W` compares the same months across years: with data to August, every FY is summed for
April-August. Put `fy` on Columns and `FYTD E2W` on Rows to get a like-for-like YoY bar chart.

### LOD or table calculation for market share?

- **Table calculation** (Percent of Total) is computed on the aggregated marks in the view. It is quick,
  but the denominator changes when you filter makers out: filter to the top 6 and they sum to 100%.
- **FIXED LOD** is computed in the data source before dimension filters (except context filters), so the
  denominator stays the whole market. Filtering to the top 6 still shows their true share.
  Use the LOD version for the Top N view. This is the same idea as `ALL(dim_maker)` in DAX:
  remove the maker filter from the denominator.
- Add `fy` (or `dim_state[state_name]`) to the LOD braces if the view is split by that dimension,
  e.g. `{ FIXED [fy], [state_name] : SUM([registrations]) }`.

### Top N makers

1. **Create Parameter** `Top N`: integer, range 3-10, current value 6. Show the parameter control.
2. **Create Set** on `maker_name`: **Top** tab, **By field**, Top `Top N` by `SUM(registrations)`.
3. Calculated field **Maker (Top N)**:
   ```
   IF [Top N Makers Set] THEN [maker_name] ELSE "Others" END
   ```
DAX equivalent: a `Maker Rank` measure with `RANKX` plus a what-if parameter, and a calculated
column or visual-level filter `Maker Rank <= [Top N Value]`.

## 3. Dashboards

**Executive Overview**
- KPI text sheets: `FYTD E2W`, `YoY Growth %` (with a ▲/▼ calculated field coloured by sign),
  `Penetration %`, and leader share (`Market Share %` of the rank-1 maker).
- Line chart: `month_start` (continuous month) vs `SUM([E2W])`, plus a reference band for festive months,
  and a moving average via **Quick table calculation > Moving Average** (3 previous values).
- FY filter applied to all worksheets using this data source.

**Competitive Landscape**
- 100% area chart: `fy_quarter` within `fy` on Columns, `Market Share % (LOD)` on Rows,
  `Maker (Top N)` on Colour.
- Bar chart: share change in percentage points, last FY vs previous, coloured by gaining or losing.
- `Top N` parameter control on the dashboard.

Use the colour order from `powerbi/theme.json` (`#2a78d6, #eb6834, #1baf7a, #eda100, #e87ba4, #008300`)
and grey `#b4b2a9` for "Others", via **Edit Colours**.

## 4. Publish and embed

1. **File > Save to Tableau Public As...**, sign in, name it "India EV Adoption & Market Share".
2. On the Tableau Public profile page, open the viz and copy the link from **Share**.
3. Put the link in `tableau/link.md` and in the README's Links section, and save dashboard screenshots
   to `images/tableau_overview.png` and `images/tableau_competition.png`.
