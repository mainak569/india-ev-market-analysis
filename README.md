# India EV Adoption & Market Share Analysis

<!-- one-line summary -->

Work in progress.

## Setup

Requires Python 3.11+ and PostgreSQL 15.

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env   # then fill in DB_PASSWORD
python src/check_connection.py
```

## Project structure

```
data/raw/          Vahan registration exports (see data/raw/README.md)
data/reference/    state population, state-to-region mapping, maker-name mapping
data/processed/    cleaned data and CSV exports for Power BI / Tableau
sql/               schema, validation and analysis queries
notebooks/         exploratory analysis
src/               Python scripts for combining, loading and exporting data
powerbi/           Power BI report and PDF export
tableau/           Tableau Public link and screenshots
images/            dashboard screenshots and data model diagram
reports/           insights summary
```
