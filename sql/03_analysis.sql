-- Business analysis: India electric two-wheeler (E2W) adoption and market share.
-- Periods are Indian financial years (April-March). "Latest FY" = the latest FY with all 12 months loaded.

-- Helper views ------------------------------------------------------------------------------

CREATE OR REPLACE VIEW v_state_month AS
SELECT d.date_key,
       d.month_start,
       d.fy,
       d.fy_start_year,
       d.fy_month_no,
       d.is_festive,
       s.state_name,
       s.region,
       s.population,
       s.has_maker_data,
       SUM(f.registrations) FILTER (WHERE fu.is_electric) AS e2w,
       SUM(f.registrations)                               AS all_2w
FROM fact_registrations f
JOIN dim_date d  ON d.date_key = f.date_key
JOIN dim_state s ON s.state_key = f.state_key
JOIN dim_fuel fu ON fu.fuel_key = f.fuel_key
GROUP BY d.date_key, d.month_start, d.fy, d.fy_start_year, d.fy_month_no, d.is_festive,
         s.state_name, s.region, s.population, s.has_maker_data;

CREATE OR REPLACE VIEW v_fy AS
SELECT fy,
       fy_start_year,
       COUNT(*)       AS months_loaded,
       COUNT(*) = 12  AS is_complete
FROM dim_date
GROUP BY fy, fy_start_year;


-- Q1. How fast is E2W adoption growing month to month?
-- National E2W registrations with MoM % change, a rolling 3-month average and penetration %.
WITH national AS (
    SELECT month_start,
           SUM(e2w)    AS e2w,
           SUM(all_2w) AS all_2w
    FROM v_state_month
    GROUP BY month_start
)
SELECT month_start,
       e2w,
       ROUND(100.0 * (e2w - LAG(e2w) OVER w) / NULLIF(LAG(e2w) OVER w, 0), 1)           AS mom_pct,
       ROUND(AVG(e2w) OVER (ORDER BY month_start ROWS BETWEEN 2 PRECEDING AND CURRENT ROW)) AS rolling_3m_avg,
       ROUND(100.0 * e2w / all_2w, 2)                                                      AS penetration_pct
FROM national
WINDOW w AS (ORDER BY month_start)
ORDER BY month_start;


-- Q2. Are we ahead of last year? FYTD registrations and YoY % for the same months of the previous FY.
WITH monthly AS (
    SELECT fy, fy_start_year, fy_month_no, month_start, SUM(e2w) AS e2w
    FROM v_state_month
    GROUP BY fy, fy_start_year, fy_month_no, month_start
),
-- an FY whose data doesn't start in April (the first, partial FY) would give a wrong running total
full_start AS (
    SELECT * FROM monthly
    WHERE fy IN (SELECT fy FROM monthly GROUP BY fy HAVING MIN(fy_month_no) = 1)
),
fytd AS (
    SELECT *,
           SUM(e2w) OVER (PARTITION BY fy ORDER BY fy_month_no) AS fytd_e2w
    FROM full_start
)
SELECT cur.fy,
       cur.month_start,
       cur.e2w,
       cur.fytd_e2w,
       prev.fytd_e2w                                                                   AS py_fytd_e2w,
       ROUND(100.0 * (cur.fytd_e2w - prev.fytd_e2w) / NULLIF(prev.fytd_e2w, 0), 1)     AS fytd_yoy_pct
FROM fytd cur
LEFT JOIN fytd prev
       ON prev.fy_start_year = cur.fy_start_year - 1
      AND prev.fy_month_no = cur.fy_month_no
ORDER BY cur.month_start;


-- Q3. Which states have gone furthest electric? Penetration % (E2W / all 2W) by state,
-- latest FY vs the FY before, change in percentage points.
WITH latest AS (
    SELECT MAX(fy_start_year) AS yr FROM v_fy WHERE is_complete
),
by_fy AS (
    SELECT state_name, fy_start_year, SUM(e2w) AS e2w, SUM(all_2w) AS all_2w
    FROM v_state_month
    GROUP BY state_name, fy_start_year
)
SELECT cur.state_name,
       cur.e2w,
       ROUND(100.0 * cur.e2w / cur.all_2w, 2)                                      AS penetration_pct,
       ROUND(100.0 * prev.e2w / prev.all_2w, 2)                                    AS prev_penetration_pct,
       ROUND(100.0 * cur.e2w / cur.all_2w - 100.0 * prev.e2w / prev.all_2w, 2)     AS change_pp
FROM by_fy cur
JOIN latest ON cur.fy_start_year = latest.yr
JOIN by_fy prev
  ON prev.state_name = cur.state_name
 AND prev.fy_start_year = latest.yr - 1
ORDER BY penetration_pct DESC;


-- Q4. Adoption adjusted for population: E2W registrations per lakh people, latest FY.
WITH latest AS (
    SELECT MAX(fy_start_year) AS yr FROM v_fy WHERE is_complete
)
SELECT v.state_name,
       SUM(v.e2w)                                                   AS e2w,
       MAX(v.population)                                            AS population,
       ROUND(SUM(v.e2w) * 100000.0 / MAX(v.population), 1)          AS e2w_per_lakh,
       RANK() OVER (ORDER BY SUM(v.e2w) * 1.0 / MAX(v.population) DESC) AS per_lakh_rank
FROM v_state_month v
JOIN latest ON v.fy_start_year = latest.yr
GROUP BY v.state_name
ORDER BY e2w_per_lakh DESC;


-- Q5. Who holds the national market? Top 10 makers by E2W registrations in the latest FY,
-- market share % and change vs the previous FY.
WITH latest AS (
    SELECT MAX(fy_start_year) AS yr FROM v_fy WHERE is_complete
),
maker_fy AS (
    SELECT m.maker_name, d.fy_start_year, SUM(f.registrations) AS e2w
    FROM fact_maker_registrations f
    JOIN dim_maker m ON m.maker_key = f.maker_key
    JOIN dim_date d  ON d.date_key = f.date_key
    GROUP BY m.maker_name, d.fy_start_year
),
share AS (
    SELECT *,
           100.0 * e2w / SUM(e2w) OVER (PARTITION BY fy_start_year) AS share_pct
    FROM maker_fy
)
SELECT RANK() OVER (ORDER BY cur.e2w DESC)                       AS rank,
       cur.maker_name,
       cur.e2w,
       ROUND(cur.share_pct, 2)                                  AS share_pct,
       ROUND(prev.share_pct, 2)                                 AS prev_share_pct,
       ROUND(cur.share_pct - COALESCE(prev.share_pct, 0), 2)    AS share_change_pp
FROM share cur
JOIN latest ON cur.fy_start_year = latest.yr
LEFT JOIN share prev
       ON prev.maker_name = cur.maker_name
      AND prev.fy_start_year = latest.yr - 1
ORDER BY cur.e2w DESC
LIMIT 10;


-- Q6. Who leads in each state? Leader and runner-up per state in the latest FY.
-- Needs Report A, so it only covers states with has_maker_data.
WITH latest AS (
    SELECT MAX(fy_start_year) AS yr FROM v_fy WHERE is_complete
),
state_maker AS (
    SELECT s.state_name, m.maker_name, SUM(f.registrations) AS e2w
    FROM fact_maker_registrations f
    JOIN dim_state s ON s.state_key = f.state_key
    JOIN dim_maker m ON m.maker_key = f.maker_key
    JOIN dim_date d  ON d.date_key = f.date_key
    JOIN latest      ON d.fy_start_year = latest.yr
    WHERE s.state_name <> 'Rest of India'
    GROUP BY s.state_name, m.maker_name
),
ranked AS (
    SELECT *,
           100.0 * e2w / SUM(e2w) OVER (PARTITION BY state_name)            AS share_pct,
           ROW_NUMBER() OVER (PARTITION BY state_name ORDER BY e2w DESC)    AS rn
    FROM state_maker
)
SELECT state_name,
       MAX(maker_name) FILTER (WHERE rn = 1)                    AS leader,
       ROUND(MAX(share_pct) FILTER (WHERE rn = 1), 1)           AS leader_share_pct,
       MAX(maker_name) FILTER (WHERE rn = 2)                    AS runner_up,
       ROUND(MAX(share_pct) FILTER (WHERE rn = 2), 1)           AS runner_up_share_pct,
       ROUND(MAX(share_pct) FILTER (WHERE rn = 1) - MAX(share_pct) FILTER (WHERE rn = 2), 1) AS lead_pp
FROM ranked
WHERE rn <= 2
GROUP BY state_name
ORDER BY leader_share_pct DESC;


-- Q7. How concentrated is each state's market? Herfindahl-Hirschman Index (HHI) = sum of squared
-- market shares (in %), range 0-10,000. Below 1,500 is usually read as competitive, 1,500-2,500 as
-- moderately concentrated, above 2,500 as highly concentrated. For a new entrant, a low HHI means
-- share is spread across many players and no incumbent controls dealers and mindshare;
-- a high HHI means taking share means taking it directly from one or two dominant brands.
WITH latest AS (
    SELECT MAX(fy_start_year) AS yr FROM v_fy WHERE is_complete
),
state_maker AS (
    SELECT s.state_name, m.maker_name, SUM(f.registrations) AS e2w
    FROM fact_maker_registrations f
    JOIN dim_state s ON s.state_key = f.state_key
    JOIN dim_maker m ON m.maker_key = f.maker_key
    JOIN dim_date d  ON d.date_key = f.date_key
    JOIN latest      ON d.fy_start_year = latest.yr
    GROUP BY s.state_name, m.maker_name
),
national AS (
    SELECT 'All India' AS state_name, maker_name, SUM(e2w) AS e2w
    FROM state_maker
    GROUP BY maker_name
),
shares AS (
    SELECT state_name, maker_name,
           100.0 * e2w / SUM(e2w) OVER (PARTITION BY state_name) AS share_pct
    FROM (
        SELECT * FROM state_maker WHERE state_name <> 'Rest of India'
        UNION ALL
        SELECT * FROM national
    ) x
)
SELECT state_name,
       ROUND(SUM(share_pct * share_pct))                     AS hhi,
       COUNT(*) FILTER (WHERE share_pct >= 1)                AS makers_with_1pct_plus,
       CASE
           WHEN SUM(share_pct * share_pct) < 1500 THEN 'Competitive'
           WHEN SUM(share_pct * share_pct) < 2500 THEN 'Moderately concentrated'
           ELSE 'Highly concentrated'
       END                                                   AS concentration
FROM shares
GROUP BY state_name
ORDER BY hhi DESC;


-- Q8. Where is the market big and where is it moving fast? State 2x2: latest-FY E2W volume vs YoY growth,
-- split at the median of each. States with under 1,000 E2W in the previous FY are left out because
-- growth on a tiny base is noise.
WITH latest AS (
    SELECT MAX(fy_start_year) AS yr FROM v_fy WHERE is_complete
),
by_state AS (
    SELECT v.state_name,
           SUM(v.e2w) FILTER (WHERE v.fy_start_year = latest.yr)     AS e2w,
           SUM(v.e2w) FILTER (WHERE v.fy_start_year = latest.yr - 1) AS prev_e2w
    FROM v_state_month v
    CROSS JOIN latest
    GROUP BY v.state_name
),
metrics AS (
    SELECT state_name, e2w, prev_e2w,
           100.0 * (e2w - prev_e2w) / prev_e2w AS yoy_pct
    FROM by_state
    WHERE prev_e2w >= 1000
),
medians AS (
    SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY e2w)     AS median_e2w,
           PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY yoy_pct) AS median_yoy
    FROM metrics
)
SELECT m.state_name,
       m.e2w,
       ROUND(m.yoy_pct, 1) AS yoy_pct,
       CASE
           WHEN m.e2w >= md.median_e2w AND m.yoy_pct >= md.median_yoy THEN 'Large & fast'
           WHEN m.e2w >= md.median_e2w                                THEN 'Large & slow'
           WHEN m.yoy_pct >= md.median_yoy                            THEN 'Small & fast'
           ELSE 'Small & slow'
       END AS quadrant
FROM metrics m
CROSS JOIN medians md
ORDER BY quadrant, m.e2w DESC;


-- Q9. Which makers are gaining or losing share? National share in the last 12 months
-- vs the 12 months before that. Makers with at least 0.5% share in either window.
WITH bounds AS (
    SELECT MAX(month_start) AS last_month FROM dim_date
),
windows AS (
    SELECT m.maker_name,
           SUM(f.registrations) FILTER (WHERE d.month_start >  b.last_month - INTERVAL '12 months') AS last_12m,
           SUM(f.registrations) FILTER (WHERE d.month_start <= b.last_month - INTERVAL '12 months'
                                          AND d.month_start >  b.last_month - INTERVAL '24 months') AS prior_12m
    FROM fact_maker_registrations f
    JOIN dim_maker m ON m.maker_key = f.maker_key
    JOIN dim_date d  ON d.date_key = f.date_key
    CROSS JOIN bounds b
    GROUP BY m.maker_name
),
shares AS (
    SELECT maker_name, last_12m, prior_12m,
           100.0 * COALESCE(last_12m, 0)  / SUM(last_12m)  OVER () AS share_last_12m,
           100.0 * COALESCE(prior_12m, 0) / SUM(prior_12m) OVER () AS share_prior_12m
    FROM windows
)
SELECT maker_name,
       last_12m,
       prior_12m,
       ROUND(share_last_12m, 2)                     AS share_last_12m_pct,
       ROUND(share_prior_12m, 2)                    AS share_prior_12m_pct,
       ROUND(share_last_12m - share_prior_12m, 2)   AS share_change_pp,
       CASE WHEN share_last_12m > share_prior_12m THEN 'Gaining' ELSE 'Losing' END AS direction
FROM shares
WHERE share_last_12m >= 0.5 OR share_prior_12m >= 0.5
ORDER BY share_change_pp DESC;


-- Q10. Is there a festive-season effect? Average monthly registrations in Sep-Nov vs the other
-- months, per complete FY, for E2W and for all two-wheelers.
SELECT v.fy,
       ROUND(SUM(v.e2w)    FILTER (WHERE v.is_festive) / 3.0)          AS e2w_festive_avg,
       ROUND(SUM(v.e2w)    FILTER (WHERE NOT v.is_festive) / 9.0)      AS e2w_other_avg,
       ROUND(100.0 * (SUM(v.e2w) FILTER (WHERE v.is_festive) / 3.0)
             / (SUM(v.e2w) FILTER (WHERE NOT v.is_festive) / 9.0) - 100, 1)    AS e2w_festive_uplift_pct,
       ROUND(100.0 * (SUM(v.all_2w) FILTER (WHERE v.is_festive) / 3.0)
             / (SUM(v.all_2w) FILTER (WHERE NOT v.is_festive) / 9.0) - 100, 1) AS all_2w_festive_uplift_pct
FROM v_state_month v
JOIN v_fy f ON f.fy = v.fy
WHERE f.is_complete
GROUP BY v.fy
ORDER BY v.fy;


-- Q11. How concentrated is demand geographically? Share of national E2W volume from the top 5 states, per FY.
WITH by_state AS (
    SELECT fy, state_name, SUM(e2w) AS e2w,
           RANK() OVER (PARTITION BY fy ORDER BY SUM(e2w) DESC) AS rnk
    FROM v_state_month
    GROUP BY fy, state_name
)
SELECT b.fy,
       f.months_loaded,
       ROUND(100.0 * SUM(e2w) FILTER (WHERE rnk <= 5) / SUM(e2w), 1)          AS top5_share_pct,
       STRING_AGG(state_name, ', ' ORDER BY rnk) FILTER (WHERE rnk <= 5)     AS top5_states
FROM by_state b
JOIN v_fy f ON f.fy = b.fy
GROUP BY b.fy, f.months_loaded
ORDER BY b.fy;


-- Q12. Which states should we prioritise? Weighted scorecard for the states with maker-level data.
-- Each factor is min-max normalised to 0-1 across the candidate states:
--   size         latest-FY E2W volume                       (bigger market = more to win)
--   growth       latest-FY YoY growth                       (momentum)
--   headroom     1 - penetration                            (room left to convert petrol buyers)
--   competition  1 - HHI                                    (fragmented market = easier entry)
-- Base weights: size 0.35, growth 0.25, headroom 0.15, competition 0.25. Size gets the most weight
-- because a new entrant needs volume to justify dealers and service; headroom gets the least because
-- low penetration can also mean low readiness (charging, awareness). The alternative weight sets below
-- test how sensitive the ranking is: a state that stays near the top in every scenario is a robust pick.
WITH latest AS (
    SELECT MAX(fy_start_year) AS yr FROM v_fy WHERE is_complete
),
state_base AS (
    SELECT v.state_name,
           SUM(v.e2w)    FILTER (WHERE v.fy_start_year = l.yr)     AS e2w,
           SUM(v.e2w)    FILTER (WHERE v.fy_start_year = l.yr - 1) AS prev_e2w,
           SUM(v.all_2w) FILTER (WHERE v.fy_start_year = l.yr)     AS all_2w
    FROM v_state_month v
    CROSS JOIN latest l
    WHERE v.has_maker_data
    GROUP BY v.state_name
),
state_hhi AS (
    SELECT state_name, SUM(share_pct * share_pct) AS hhi
    FROM (
        SELECT s.state_name,
               100.0 * SUM(f.registrations) / SUM(SUM(f.registrations)) OVER (PARTITION BY s.state_name) AS share_pct
        FROM fact_maker_registrations f
        JOIN dim_state s ON s.state_key = f.state_key
        JOIN dim_maker m ON m.maker_key = f.maker_key
        JOIN dim_date d  ON d.date_key = f.date_key
        JOIN latest l    ON d.fy_start_year = l.yr
        WHERE s.state_name <> 'Rest of India'
        GROUP BY s.state_name, m.maker_name
    ) x
    GROUP BY state_name
),
raw_factors AS (
    SELECT b.state_name,
           b.e2w::NUMERIC                                  AS size,
           (b.e2w - b.prev_e2w)::NUMERIC / b.prev_e2w      AS growth,
           1 - b.e2w::NUMERIC / b.all_2w                   AS headroom,
           h.hhi
    FROM state_base b
    JOIN state_hhi h ON h.state_name = b.state_name
),
normalised AS (
    SELECT state_name, size, growth, headroom, hhi,
           (size - MIN(size) OVER ())         / NULLIF(MAX(size) OVER () - MIN(size) OVER (), 0)         AS n_size,
           (growth - MIN(growth) OVER ())     / NULLIF(MAX(growth) OVER () - MIN(growth) OVER (), 0)     AS n_growth,
           (headroom - MIN(headroom) OVER ()) / NULLIF(MAX(headroom) OVER () - MIN(headroom) OVER (), 0) AS n_headroom,
           (MAX(hhi) OVER () - hhi)           / NULLIF(MAX(hhi) OVER () - MIN(hhi) OVER (), 0)           AS n_competition
    FROM raw_factors
),
weights (scenario, w_size, w_growth, w_headroom, w_competition) AS (
    VALUES ('base',          0.35, 0.25, 0.15, 0.25),
           ('equal',         0.25, 0.25, 0.25, 0.25),
           ('growth_led',    0.20, 0.45, 0.15, 0.20),
           ('size_led',      0.55, 0.15, 0.10, 0.20)
),
scored AS (
    SELECT w.scenario, n.*,
           n.n_size * w.w_size + n.n_growth * w.w_growth
             + n.n_headroom * w.w_headroom + n.n_competition * w.w_competition AS score
    FROM normalised n
    CROSS JOIN weights w
),
ranked AS (
    SELECT *, RANK() OVER (PARTITION BY scenario ORDER BY score DESC) AS rnk
    FROM scored
)
SELECT state_name,
       ROUND(MAX(size))                                       AS e2w,
       ROUND(100 * MAX(growth), 1)                            AS yoy_pct,
       ROUND(100 * (1 - MAX(headroom)), 2)                    AS penetration_pct,
       ROUND(MAX(hhi))                                        AS hhi,
       ROUND(MAX(score) FILTER (WHERE scenario = 'base'), 3)  AS base_score,
       MAX(rnk) FILTER (WHERE scenario = 'base')              AS base_rank,
       MAX(rnk) FILTER (WHERE scenario = 'equal')             AS equal_rank,
       MAX(rnk) FILTER (WHERE scenario = 'growth_led')        AS growth_led_rank,
       MAX(rnk) FILTER (WHERE scenario = 'size_led')          AS size_led_rank,
       MAX(rnk) - MIN(rnk)                                    AS rank_spread
FROM ranked
GROUP BY state_name
ORDER BY base_rank;
