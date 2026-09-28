# Raw data

All files are downloaded manually from the Vahan dashboard report page:
https://vahan.parivahan.gov.in/vahan4dashboard/vahan/view/reportview.xhtml

## Settings used in every file

- **Type:** Actual Value
- **Year Type:** Financial Year
- **Vehicle Class** (left panel): tick these seven two-wheeler classes and nothing else
  - M-CYCLE/SCOOTER
  - M-CYCLE/SCOOTER-WITH SIDE CAR
  - MOPED
  - MOTORISED CYCLE (CC > 25CC)
  - MOTOR CYCLE/SCOOTER-SIDECAR(T)
  - MOTOR CYCLE/SCOOTER-WITH TRAILER
  - MOTOR CYCLE/SCOOTER-USED FOR HIRE
- **Fuel** (left panel), electric reports only: tick ELECTRIC(BOV) and PURE EV.
  Vahan records electric vehicles under both labels, so both are needed.

The same vehicle classes are used in every report so that E2W and all-2W counts
share one definition of "two-wheeler" and penetration % is like-for-like.

Click Refresh after changing any setting and check that the table updated before downloading.
Check that the title row of each downloaded file shows the financial year you intended.

## Reports

| Report | Y-Axis | X-Axis     | State                 | Fuel filter | Files          |
|--------|--------|------------|-----------------------|-------------|----------------|
| B      | State  | Month Wise | All Vahan4 Running States | none    | 1 per FY       |
| C      | State  | Month Wise | All Vahan4 Running States | electric | 1 per FY      |
| D      | Maker  | Month Wise | All Vahan4 Running States | electric | 1 per FY      |
| E      | Fuel   | Month Wise | All Vahan4 Running States | none    | 1 per FY (optional) |
| A      | Maker  | Month Wise | one state             | electric    | 1 per state per FY |

- **B**: all two-wheelers by state and month, the base for EV penetration %.
- **C**: electric two-wheelers by state and month, for all states.
- **D**: electric two-wheelers by maker and month, all-India. Used for national market share.
- **E**: all two-wheelers by fuel and month, all-India. Cross-check for B and C, plus national fuel mix.
- **A**: electric two-wheelers by maker and month within one state. Used for state-level
  market share, leaders and HHI. Downloaded only for the states listed below.

## Financial years

FY2023-24, FY2024-25, FY2025-26, and FY2026-27 to date.

Download the current-FY files after a month has ended, all on the same day,
and record the date below. The latest month can still change for a few days after it ends.

## File names

```
B_2w_state_FY2024-25.xlsx
C_e2w_state_FY2024-25.xlsx
D_e2w_maker_india_FY2024-25.xlsx
E_2w_fuel_india_FY2024-25.xlsx
A_e2w_maker_<state>_FY2024-25.xlsx
```

`<state>` is lowercase with underscores, e.g. `A_e2w_maker_uttar_pradesh_FY2024-25.xlsx`.

## States covered by Report A

To be filled in from Report C: the smallest set of states covering most E2W volume.

## Download log

| Files | Downloaded on |
|-------|---------------|
|       |               |

## Known limitations

- Vahan counts registrations, not sales or dispatches.
- Low-speed electric two-wheelers (top speed up to 25 km/h, motor up to 250 W) do not need
  registration, so they are not in Vahan.
