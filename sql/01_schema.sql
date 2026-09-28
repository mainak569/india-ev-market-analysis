-- Star schema for India two-wheeler registrations (Vahan).
-- Vahan only exports two-dimensional pivots, so there are two fact tables at their natural grain:
--   fact_registrations        state x month x fuel group, all states (Reports B and C)
--   fact_maker_registrations  state x month x maker, electric only (Reports A and D)
-- Staging tables hold the combined raw exports untouched, for validation.

DROP TABLE IF EXISTS fact_maker_registrations, fact_registrations CASCADE;
DROP TABLE IF EXISTS dim_date, dim_state, dim_maker, dim_fuel, dim_vehicle_category CASCADE;
DROP TABLE IF EXISTS stg_all2w_state_month, stg_e2w_state_month, stg_e2w_maker_month_india, stg_e2w_maker_month_state CASCADE;

CREATE TABLE stg_all2w_state_month (
    state         TEXT    NOT NULL,
    year          INTEGER NOT NULL,
    month         INTEGER NOT NULL,
    registrations INTEGER NOT NULL
);

CREATE TABLE stg_e2w_state_month (LIKE stg_all2w_state_month);

CREATE TABLE stg_e2w_maker_month_india (
    maker_raw     TEXT    NOT NULL,
    year          INTEGER NOT NULL,
    month         INTEGER NOT NULL,
    registrations INTEGER NOT NULL
);

CREATE TABLE stg_e2w_maker_month_state (
    state         TEXT    NOT NULL,
    maker_raw     TEXT    NOT NULL,
    year          INTEGER NOT NULL,
    month         INTEGER NOT NULL,
    registrations INTEGER NOT NULL
);

CREATE TABLE dim_date (
    date_key       INTEGER PRIMARY KEY,          -- YYYYMM
    month_start    DATE    NOT NULL UNIQUE,
    calendar_year  INTEGER NOT NULL,
    month_no       INTEGER NOT NULL CHECK (month_no BETWEEN 1 AND 12),
    month_name     TEXT    NOT NULL,
    fy             TEXT    NOT NULL,             -- e.g. FY2024-25 (April to March)
    fy_start_year  INTEGER NOT NULL,
    fy_quarter     TEXT    NOT NULL,             -- Q1 = Apr-Jun
    fy_month_no    INTEGER NOT NULL CHECK (fy_month_no BETWEEN 1 AND 12),
    is_festive     BOOLEAN NOT NULL              -- Sep to Nov (Navratri, Dussehra, Diwali)
);

CREATE TABLE dim_state (
    state_key       SERIAL PRIMARY KEY,
    state_name      TEXT   NOT NULL UNIQUE,
    vahan_name      TEXT,
    region          TEXT   NOT NULL,
    population      BIGINT,                      -- projection as on 1 Oct 2025
    has_maker_data  BOOLEAN NOT NULL             -- true if Report A was downloaded for the state
);

CREATE TABLE dim_maker (
    maker_key     SERIAL PRIMARY KEY,
    maker_raw     TEXT NOT NULL UNIQUE,
    maker_name    TEXT NOT NULL,
    parent_group  TEXT NOT NULL
);

CREATE TABLE dim_fuel (
    fuel_key     SERIAL PRIMARY KEY,
    fuel_group   TEXT    NOT NULL UNIQUE,
    is_electric  BOOLEAN NOT NULL,
    vahan_fuels  TEXT    NOT NULL
);

CREATE TABLE dim_vehicle_category (
    vehicle_category_key  SERIAL PRIMARY KEY,
    category_name         TEXT NOT NULL UNIQUE,
    vahan_categories      TEXT NOT NULL
);

CREATE TABLE fact_registrations (
    date_key              INTEGER NOT NULL REFERENCES dim_date (date_key),
    state_key             INTEGER NOT NULL REFERENCES dim_state (state_key),
    fuel_key              INTEGER NOT NULL REFERENCES dim_fuel (fuel_key),
    vehicle_category_key  INTEGER NOT NULL REFERENCES dim_vehicle_category (vehicle_category_key),
    registrations         INTEGER NOT NULL CHECK (registrations >= 0),
    PRIMARY KEY (date_key, state_key, fuel_key, vehicle_category_key)
);

CREATE TABLE fact_maker_registrations (
    date_key              INTEGER NOT NULL REFERENCES dim_date (date_key),
    state_key             INTEGER NOT NULL REFERENCES dim_state (state_key),
    maker_key             INTEGER NOT NULL REFERENCES dim_maker (maker_key),
    fuel_key              INTEGER NOT NULL REFERENCES dim_fuel (fuel_key),
    vehicle_category_key  INTEGER NOT NULL REFERENCES dim_vehicle_category (vehicle_category_key),
    registrations         INTEGER NOT NULL CHECK (registrations >= 0),
    PRIMARY KEY (date_key, state_key, maker_key)
);

CREATE INDEX idx_fact_reg_state ON fact_registrations (state_key);
CREATE INDEX idx_fact_maker_maker ON fact_maker_registrations (maker_key);
CREATE INDEX idx_fact_maker_state ON fact_maker_registrations (state_key);
