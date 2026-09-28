-- Data validation. Every check returns the number of failing rows; 0 means the check passed.
-- Staging tables hold the raw exports as downloaded (including the incomplete latest month),
-- so comparisons are limited to months present in dim_date.

-- 1. All-2W totals in the fact table reconcile to Report B, per state and month
WITH fact AS (
    SELECT f.date_key, s.state_name, SUM(f.registrations) AS registrations
    FROM fact_registrations f
    JOIN dim_state s ON s.state_key = f.state_key
    GROUP BY f.date_key, s.state_name
),
raw AS (
    SELECT year * 100 + month AS date_key, state, registrations
    FROM stg_all2w_state_month
    WHERE year * 100 + month IN (SELECT date_key FROM dim_date)
)
SELECT '1. fact_registrations total = Report B' AS check_name, COUNT(*) AS failures
FROM raw
FULL JOIN fact ON fact.date_key = raw.date_key AND fact.state_name = raw.state
WHERE raw.registrations IS DISTINCT FROM fact.registrations

UNION ALL

-- 2. Electric rows reconcile to Report C, per state and month
SELECT '2. fact_registrations electric = Report C', COUNT(*)
FROM stg_e2w_state_month c
JOIN dim_state s ON s.state_name = c.state
LEFT JOIN fact_registrations f
       ON f.date_key = c.year * 100 + c.month
      AND f.state_key = s.state_key
      AND f.fuel_key = (SELECT fuel_key FROM dim_fuel WHERE is_electric)
WHERE c.year * 100 + c.month IN (SELECT date_key FROM dim_date)
  AND f.registrations IS DISTINCT FROM c.registrations

UNION ALL

-- 3. Report D (by maker) and Report C (by state) give the same national E2W total each month
SELECT '3. Report D national total = Report C national total', COUNT(*)
FROM (
    SELECT year, month, SUM(registrations) AS by_maker
    FROM stg_e2w_maker_month_india
    GROUP BY year, month
) d
FULL JOIN (
    SELECT year, month, SUM(registrations) AS by_state
    FROM stg_e2w_state_month
    GROUP BY year, month
) c USING (year, month)
WHERE d.by_maker IS DISTINCT FROM c.by_state

UNION ALL

-- 4. Maker fact sums back to Report D per maker and month (state rows + Rest of India)
SELECT '4. fact_maker_registrations = Report D per maker-month', COUNT(*)
FROM (
    SELECT d.year * 100 + d.month AS date_key, m.maker_key, d.registrations
    FROM stg_e2w_maker_month_india d
    JOIN dim_maker m ON m.maker_raw = d.maker_raw
    WHERE d.year * 100 + d.month IN (SELECT date_key FROM dim_date)
      AND d.registrations > 0
) raw
FULL JOIN (
    SELECT date_key, maker_key, SUM(registrations) AS registrations
    FROM fact_maker_registrations
    GROUP BY date_key, maker_key
) fact USING (date_key, maker_key)
WHERE raw.registrations IS DISTINCT FROM fact.registrations

UNION ALL

-- 5. For states with Report A, maker totals match that state's Report C total
SELECT '5. Report A state totals = Report C', COUNT(*)
FROM (
    SELECT state, year, month, SUM(registrations) AS by_maker
    FROM stg_e2w_maker_month_state
    GROUP BY state, year, month
) a
JOIN stg_e2w_state_month c USING (state, year, month)
WHERE a.by_maker <> c.registrations

UNION ALL

-- 6. No negative counts (also enforced by CHECK constraints)
SELECT '6. negative registrations', COUNT(*)
FROM (
    SELECT registrations FROM fact_registrations
    UNION ALL
    SELECT registrations FROM fact_maker_registrations
) f
WHERE registrations < 0

UNION ALL

-- 7. No orphan keys (also enforced by foreign keys)
SELECT '7. orphan keys', COUNT(*)
FROM fact_registrations f
LEFT JOIN dim_date d ON d.date_key = f.date_key
LEFT JOIN dim_state s ON s.state_key = f.state_key
WHERE d.date_key IS NULL OR s.state_key IS NULL

UNION ALL

-- 8. No duplicate rows at the fact grain
SELECT '8. duplicate grain rows', COUNT(*)
FROM (
    SELECT date_key, state_key, fuel_key
    FROM fact_registrations
    GROUP BY date_key, state_key, fuel_key
    HAVING COUNT(*) > 1
) dup

UNION ALL

-- 9. Every state has a row for every month and fuel group (no silent gaps)
SELECT '9. missing state-month-fuel rows', COUNT(*)
FROM dim_date d
CROSS JOIN dim_state s
CROSS JOIN dim_fuel fu
LEFT JOIN fact_registrations f
       ON f.date_key = d.date_key AND f.state_key = s.state_key AND f.fuel_key = fu.fuel_key
WHERE s.state_name <> 'Rest of India'
  AND f.date_key IS NULL

ORDER BY check_name;
