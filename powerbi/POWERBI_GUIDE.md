# Power BI build guide

Power BI Desktop runs on Windows only. The report imports the CSVs in `data/processed/`
(run `python src/export_for_bi.py` first), so it does not need a PostgreSQL connection.

## 1. Load the data

1. **Home > Get data > Text/CSV**. Load these six files from `data/processed/`:
   `dim_state`, `dim_maker`, `dim_fuel`, `dim_vehicle_category`, `fact_registrations`, `fact_maker_registrations`.
   `dim_date.csv` is not needed, because the DAX date table below replaces it.
2. Click **Transform data**. In both fact tables, add a month-start date so the facts can join a daily date table:
   **Add Column > Custom Column**, name `MonthStart`:
   ```
   #date(Number.IntegerDivide([date_key], 100), Number.Mod([date_key], 100), 1)
   ```
   Set its type to **Date**. Check the types: keys are Whole Number, `registrations` is Whole Number,
   `population` is Whole Number, `is_electric` and `has_maker_data` are True/False.
3. **Close & Apply**.

## 2. Date table (DAX)

**Modeling > New table**:

```DAX
Date =
VAR LastDataDate = EOMONTH ( MAX ( fact_registrations[MonthStart] ), 0 )
RETURN
    ADDCOLUMNS (
        CALENDAR ( DATE ( 2023, 1, 1 ), LastDataDate ),
        "Year", YEAR ( [Date] ),
        "Month No", MONTH ( [Date] ),
        "Month", FORMAT ( [Date], "MMM" ),
        "Month Year", FORMAT ( [Date], "MMM yy" ),
        "MonthStart", DATE ( YEAR ( [Date] ), MONTH ( [Date] ), 1 ),
        "FY Start Year", IF ( MONTH ( [Date] ) >= 4, YEAR ( [Date] ), YEAR ( [Date] ) - 1 ),
        "FY", "FY" & IF ( MONTH ( [Date] ) >= 4, YEAR ( [Date] ), YEAR ( [Date] ) - 1 )
                & "-" & RIGHT ( IF ( MONTH ( [Date] ) >= 4, YEAR ( [Date] ) + 1, YEAR ( [Date] ) ), 2 ),
        "FY Month No", MOD ( MONTH ( [Date] ) - 4, 12 ) + 1,
        "FY Quarter", "Q" & ROUNDUP ( ( MOD ( MONTH ( [Date] ) - 4, 12 ) + 1 ) / 3, 0 ),
        "Is Festive", MONTH ( [Date] ) IN { 9, 10, 11 }
    )
```

- Select the table, then **Table tools > Mark as date table** and choose `Date[Date]`.
- Sort `Month` by `Month No`, `Month Year` by `MonthStart`, and `FY Quarter` by `FY Month No`.
- The table ends at the last month with data (August 2026). This matters: if it ran to March 2027,
  the prior-year comparison for the current FY would compare 5 months against a full 12.

## 3. Relationships (Model view)

| From (many) | To (one) | Cross-filter |
|---|---|---|
| `fact_registrations[MonthStart]` | `Date[Date]` | Single |
| `fact_registrations[state_key]` | `dim_state[state_key]` | Single |
| `fact_registrations[fuel_key]` | `dim_fuel[fuel_key]` | Single |
| `fact_registrations[vehicle_category_key]` | `dim_vehicle_category[vehicle_category_key]` | Single |
| `fact_maker_registrations[MonthStart]` | `Date[Date]` | Single |
| `fact_maker_registrations[state_key]` | `dim_state[state_key]` | Single |
| `fact_maker_registrations[maker_key]` | `dim_maker[maker_key]` | Single |
| `fact_maker_registrations[fuel_key]` | `dim_fuel[fuel_key]` | Single |

Why single direction: filters flow from dimensions to facts, which is all the report needs.
Both-direction filters between two fact tables through shared dimensions create ambiguous paths and
slow the model. `dim_maker` only connects to `fact_maker_registrations`, so slicing by maker does not
(and should not) filter the state-level fact.

Why two facts: Vahan exports two-dimensional pivots. State x month x fuel comes from one set of
reports and state x month x maker from another, so each fact keeps its natural grain.
`fact_maker_registrations` has state-level rows for states with Report A plus a "Rest of India" row.

Hide `date_key`, all `_key` columns and `MonthStart` in the fact tables from report view.

## 4. Measures

**Home > Enter data**, create an empty table named `_Measures`, and add these measures to it.

```DAX
E2W Registrations =
CALCULATE ( SUM ( fact_registrations[registrations] ), dim_fuel[is_electric] = TRUE () )

All 2W Registrations =
SUM ( fact_registrations[registrations] )

Penetration % =
DIVIDE ( [E2W Registrations], [All 2W Registrations] )

FYTD E2W =
TOTALYTD ( [E2W Registrations], 'Date'[Date], "03-31" )

PY FYTD E2W =
CALCULATE ( [FYTD E2W], SAMEPERIODLASTYEAR ( 'Date'[Date] ) )

FYTD YoY % =
DIVIDE ( [FYTD E2W] - [PY FYTD E2W], [PY FYTD E2W] )

E2W PY =
CALCULATE ( [E2W Registrations], SAMEPERIODLASTYEAR ( 'Date'[Date] ) )

E2W YoY % =
DIVIDE ( [E2W Registrations] - [E2W PY], [E2W PY] )

MoM % =
VAR Curr = [E2W Registrations]
VAR Prev = CALCULATE ( [E2W Registrations], DATEADD ( 'Date'[Date], -1, MONTH ) )
RETURN DIVIDE ( Curr - Prev, Prev )

Rolling 3M Avg =
CALCULATE (
    [E2W Registrations],
    DATESINPERIOD ( 'Date'[Date], MAX ( 'Date'[Date] ), -3, MONTH )
) / 3

Maker E2W =
SUM ( fact_maker_registrations[registrations] )

Market Share % =
DIVIDE ( [Maker E2W], CALCULATE ( [Maker E2W], ALL ( dim_maker ) ) )

Maker Rank =
IF (
    HASONEVALUE ( dim_maker[maker_name] ),
    RANKX ( ALL ( dim_maker[maker_name] ), [Maker E2W], , DESC, DENSE )
)

HHI =
SUMX ( VALUES ( dim_maker[maker_name] ), ( [Market Share %] * 100 ) ^ 2 )

Leader Share % =
MAXX ( VALUES ( dim_maker[maker_name] ), [Market Share %] )

E2W per Lakh =
DIVIDE ( [E2W Registrations], SUM ( dim_state[population] ) ) * 100000
```

`E2W per Lakh` uses a single population figure (1 Oct 2025 projection), so read it with one FY selected.

### Scorecard with what-if weights

**Modeling > New parameter > Numeric range** four times: `W Size`, `W Growth`, `W Headroom`,
`W Competition`, each 0 to 1, increment 0.05, defaults 0.35 / 0.25 / 0.15 / 0.25. Tick "Add slicer to this page".

```DAX
Norm Size =
VAR v = [E2W Registrations]
VAR mn = MINX ( ALLSELECTED ( dim_state[state_name] ), [E2W Registrations] )
VAR mx = MAXX ( ALLSELECTED ( dim_state[state_name] ), [E2W Registrations] )
RETURN DIVIDE ( v - mn, mx - mn )

Norm Growth =
VAR v = [E2W YoY %]
VAR mn = MINX ( ALLSELECTED ( dim_state[state_name] ), [E2W YoY %] )
VAR mx = MAXX ( ALLSELECTED ( dim_state[state_name] ), [E2W YoY %] )
RETURN DIVIDE ( v - mn, mx - mn )

Norm Headroom =
VAR v = 1 - [Penetration %]
VAR mn = MINX ( ALLSELECTED ( dim_state[state_name] ), 1 - [Penetration %] )
VAR mx = MAXX ( ALLSELECTED ( dim_state[state_name] ), 1 - [Penetration %] )
RETURN DIVIDE ( v - mn, mx - mn )

Norm Competition =
VAR v = [HHI]
VAR mn = MINX ( ALLSELECTED ( dim_state[state_name] ), [HHI] )
VAR mx = MAXX ( ALLSELECTED ( dim_state[state_name] ), [HHI] )
RETURN DIVIDE ( mx - v, mx - mn )

Scorecard Score =
VAR wS = [W Size Value]
VAR wG = [W Growth Value]
VAR wH = [W Headroom Value]
VAR wC = [W Competition Value]
RETURN
    DIVIDE (
        [Norm Size] * wS + [Norm Growth] * wG + [Norm Headroom] * wH + [Norm Competition] * wC,
        wS + wG + wH + wC
    )

Scorecard Rank =
RANKX ( ALLSELECTED ( dim_state[state_name] ), [Scorecard Score], , DESC, DENSE )
```

On the scorecard page, filter the page to `dim_state[has_maker_data] = True` and
`dim_state[state_name] <> "Rest of India"`, and set the FY slicer to the latest complete FY.
Dividing by the sum of weights keeps the score on a 0-1 scale while the sliders move.

### Dynamic title

```DAX
Title Text =
"E2W registrations | "
    & SELECTEDVALUE ( 'Date'[FY], "All FYs" ) & " | "
    & SELECTEDVALUE ( dim_state[state_name], "All India" )
```

Use it in a visual's title: **Format > General > Title > fx > Field value > Title Text**.

### Four DAX ideas to be able to explain

- **CALCULATE** evaluates an expression under a modified filter context. `E2W Registrations` is
  `SUM(registrations)` with the fuel filter forced to electric, whatever the visual is filtering.
- **Filter context** is the set of filters coming from the visual, slicers and page. A card on a page
  filtered to Karnataka and FY2025-26 sums only those fact rows, before any CALCULATE changes it.
- **ALL / ALLEXCEPT** remove filters. `ALL(dim_maker)` in `Market Share %` removes the maker filter so the
  denominator is the total for the current state and period. `ALLEXCEPT(dim_state, dim_state[region])`
  would remove every state filter except region.
- **Time intelligence** (`TOTALYTD`, `SAMEPERIODLASTYEAR`, `DATEADD`, `DATESINPERIOD`) shifts or extends the
  date filter using the marked date table. `"03-31"` makes the year end on 31 March, the Indian FY.

## 5. Pages

Apply the theme first: **View > Themes > Browse for themes > `powerbi/theme.json`**.
Put an FY slicer and a region slicer on every page and sync them (**View > Sync slicers**).

### Page 1: Executive Overview
```
+------------------------------------------------------------------+
| Title Text                                   [FY v] [Region v]   |
+-------------+-------------+-------------+------------------------+
| FYTD E2W    | FYTD YoY %  | Penetration | Leader share           |
| (card)      | (card+arrow)| % (card)    | (card)                 |
+-------------+-------------+-------------+------------------------+
| Line: E2W Registrations + Rolling 3M Avg by Month Year           |
|                                                                   |
+-------------------------------------------------------------------+
```
Conditional arrow: add a measure `YoY Arrow = IF([FYTD YoY %] >= 0, "▲", "▼")` next to the
YoY card, with font colour rules: green when `[FYTD YoY %] >= 0`, red otherwise.

### Page 2: Time Intelligence
```
+-------------------------------+-----------------------------------+
| Clustered column: FYTD E2W vs | Line: MoM % by Month Year         |
| PY FYTD E2W by FY Month No    |                                   |
+-------------------------------+-----------------------------------+
| Column: E2W Registrations by Month Year, conditional colour on    |
| Is Festive (festive months highlighted), Rolling 3M Avg as line   |
+-------------------------------------------------------------------+
```

### Page 3: State View
```
+-----------------------------------+-------------------------------+
| Filled map: dim_state[state_name] | Table: state, E2W, Penetration|
| colour = Penetration % (or        | %, E2W YoY %, E2W per Lakh    |
| E2W per Lakh via bookmark)        | (sorted, data bars)           |
+-----------------------------------+-------------------------------+
```
Set the map's location field to `state_name` with **Data category = State or Province** and
add a column `Country = "India"` to `dim_state` to avoid geocoding mismatches.
Right-click drill-through goes to **State Detail**.

### Page 3b: State Detail (drill-through)
Drill-through field: `dim_state[state_name]`.
```
+---------------------------+---------------------------------------+
| Cards: E2W, Penetration %,| Bar: Market Share % by maker (top 10) |
| HHI, Leader Share %       |                                       |
+---------------------------+---------------------------------------+
| Line: E2W Registrations by Month Year                             |
+-------------------------------------------------------------------+
```
Maker visuals only show data for states that have Report A (`has_maker_data`).

### Page 4: Competitive Landscape
```
+-------------------------------------------------------------------+
| 100% stacked area: Market Share % by FY Quarter, legend = maker   |
| (filter visual to Maker Rank <= 6)                                |
+-------------------------------+-----------------------------------+
| Bar: share change (pp),       | Table: maker, Maker E2W, Market   |
| gainers vs losers             | Share %, Maker Rank               |
+-------------------------------+-----------------------------------+
```
Share change measure:
```DAX
Share Change pp =
VAR Curr = [Market Share %]
VAR Prev = CALCULATE ( [Market Share %], SAMEPERIODLASTYEAR ( 'Date'[Date] ) )
RETURN ( Curr - Prev ) * 100
```
Add a drill-through page on `dim_maker[maker_name]` showing that maker's share by state and over time.

### Page 5: Expansion Scorecard
```
+-------------------------------+-----------------------------------+
| Scatter: x = E2W Registrations| Table: state, Scorecard Score,    |
| y = E2W YoY %, size = HHI,    | Scorecard Rank, Norm columns      |
| constant lines at medians     |                                   |
+-------------------------------+-----------------------------------+
| Slicers: W Size  W Growth  W Headroom  W Competition              |
+-------------------------------------------------------------------+
```
Median lines: **Analytics pane > Median line** on both axes.

### Page 6: Insights & Recommendations
Text boxes with your own wording: top 5 states to prioritise and why, key risks, data limitations.

## 6. Features

- **Bookmarks**: on the State View page, create two bookmarks, "Share view" (map coloured by Penetration %)
  and "Volume view" (map coloured by E2W per Lakh). Add two buttons with **Action > Bookmark**.
- **Tooltip page**: new page, **Page information > Allow use as tooltip**, canvas size Tooltip.
  Put a small line of E2W Registrations by Month Year and a Penetration % card. On the map,
  **Format > Tooltips > Type: Report page** and pick it.
- **RLS by region**: **Modeling > Manage roles > New**, one role per region, table `dim_state`,
  filter `[region] = "South"` (and so on). Test with **Modeling > View as > South**: the map should
  show only southern states and national cards should drop to the South total. After publishing, assign
  users to roles in the Power BI service dataset **Security** page.

## 7. Wrap-up

- **PDF**: **File > Export > Export to PDF** and save as `powerbi/india_ev_dashboard.pdf`.
- **Screenshots**: set the page view to **Fit to page**, hide the Filters pane, and use
  **Win + Shift + S**. Save to `images/` as `pbi_<page>.png`.
- **Walkthrough GIF/video (60-90 s)**: record with **Win + G** (Xbox Game Bar) or ScreenToGif. Flow:
  Executive Overview > change FY slicer > State View > drill into a state > Competitive Landscape >
  move a scorecard weight slider. Save the GIF to `images/walkthrough.gif`.
- Save the report as `powerbi/india_ev_dashboard.pbix`.
