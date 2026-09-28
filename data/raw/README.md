# Raw data

All files are downloaded manually from the Vahan dashboard report page:
https://vahan.parivahan.gov.in/vahan4dashboard/vahan/view/reportview.xhtml

This dashboard is being replaced by https://analytics.parivahan.gov.in/analytics/vahanpublicreport
(the new one asks for a CAPTCHA on every report). The settings below are for the old dashboard.

## Settings used in every file

- **Type:** Actual Value
- **X-Axis:** Month Wise
- **Year Type:** Calendar Year. With Month Wise, the Financial Year option returns the same
  Jan-Dec table, so calendar years are downloaded and the FY is derived from each month in code.
- **Vehicle Category** (left filter panel): tick TWO WHEELER(NT), TWO WHEELER(T) and
  TWO WHEELER (Invalid Carriage). This matches Vahan's own "Two Wheeler" category group.
- **Fuel** (left filter panel), electric reports only: tick ELECTRIC(BOV) and PURE EV.
  Vahan records electric vehicles under both labels, so both are needed.
- Click the Refresh button inside the filter panel after ticking, then the Excel icon next to the table title.

The Excel title row does not record the filters, so name each file right after downloading it.

## Reports

| Report | Y-Axis | State                     | Fuel filter | Files                  |
|--------|--------|---------------------------|-------------|------------------------|
| B      | State  | All Vahan4 Running States | none        | 1 per year             |
| C      | State  | All Vahan4 Running States | electric    | 1 per year             |
| D      | Maker  | All Vahan4 Running States | electric    | 1 per year             |
| A      | Maker  | one state                 | electric    | 1 per state per year   |

- **B**: all two-wheelers by state and month, the base for EV penetration %.
- **C**: electric two-wheelers by state and month, for all states.
- **D**: electric two-wheelers by maker and month, all-India. Used for national market share.
- **A**: electric two-wheelers by maker and month within one state, for the largest E2W states only.

Years: 2023, 2024, 2025 and 2026 to date. Together they cover FY2023-24 to FY2026-27 to date.

## File names

```
B_2w_state_CY2024.xlsx
C_e2w_state_CY2024.xlsx
D_e2w_maker_india_CY2024.xlsx
A_e2w_maker_<state>_CY2024.xlsx
```

`<state>` is the state name in lowercase with underscores, e.g. `A_e2w_maker_uttar_pradesh_CY2024.xlsx`.

## Download log

| Files | Downloaded on |
|-------|---------------|
| B, C, D for 2023-2026 | 2026-09-28 |
| A (10 states, 2025-2026) | 2026-09-28 |

## Known limitations

- Vahan counts registrations, not sales or dispatches.
- Low-speed electric two-wheelers (top speed up to 25 km/h, motor up to 250 W) do not need
  registration, so they are not in Vahan.
- The latest month is incomplete at download time; the loader drops months after the last complete one.
