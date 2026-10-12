"""
load_cfpb_to_snowflake.py
=========================
MASY1-GC1500 Database Management - Capstone Milestone 2 (Group 8)
Owner: Keyanna Bernard (krb9975), Data Engineer

Loads the CFPB Consumer Complaint snapshot into Snowflake and populates the
3NF schema in CFPB_CAPSTONE_DB.CFPB_SCHEMA, end to end, with no manual steps.

The script follows the course's five-pattern approach:
    1. CONNECT    - build a SQLAlchemy engine for Snowflake
    2. EXTRACT    - pandas.read_csv on the frozen CFPB snapshot
    3. TRANSFORM  - rename and clean columns to match RAW_COMPLAINTS
    4. LOAD       - DataFrame.to_sql into the RAW_COMPLAINTS staging table,
                    then set-based INSERT ... SELECT into the 3NF tables
    5. VERIFY     - row counts and a batch entry in COMPLAINT_DQA_AUDIT

Setup (once):
    pip install pandas "snowflake-connector-python[pandas]" snowflake-sqlalchemy "sqlalchemy<2.1"

Credentials are read from environment variables, never hard-coded:
    SNOWFLAKE_ACCOUNT        e.g. gsvfbpn-hl39049   (org-account from the Snowsight URL)
    SNOWFLAKE_USER           e.g. KRB9975
    SNOWFLAKE_PASSWORD       (omit when using externalbrowser)
    SNOWFLAKE_AUTHENTICATOR  optional: "externalbrowser" for Google/SSO sign-in
    SNOWFLAKE_ROLE           optional, default PUBLIC (the team grants it
                             SELECT/INSERT/UPDATE/DELETE on the schema)
    SNOWFLAKE_WAREHOUSE      optional, default COMPUTE_WH

Usage:
    python load_cfpb_to_snowflake.py complaints.csv              # 10,000-row sample
    python load_cfpb_to_snowflake.py complaints.csv --rows 0     # full file
"""

import argparse
import os
import sys
import uuid

import pandas as pd
from snowflake.sqlalchemy import URL
from sqlalchemy import create_engine, text

DATABASE = "CFPB_CAPSTONE_DB"
SCHEMA = "CFPB_SCHEMA"

# CFPB CSV header -> RAW_COMPLAINTS column (the 15 columns that table stages).
# Narrative, consent and dispute columns are not staged in the deployed table.
COLUMN_MAP = {
    "Date received": "DATE_RECEIVED",
    "Product": "PRODUCT",
    "Sub-product": "SUB_PRODUCT",
    "Issue": "ISSUE",
    "Sub-issue": "SUB_ISSUE",
    "Company public response": "COMPANY_PUBLIC_RESPONSE",
    "Company": "COMPANY",
    "State": "STATE",
    "ZIP code": "ZIP_CODE",
    "Tags": "TAGS",
    "Submitted via": "SUBMITTED_VIA",
    "Date sent to company": "DATE_SENT_TO_COMPANY",
    "Company response to consumer": "COMPANY_RESPONSE_TO_CONSUMER",
    "Timely response?": "TIMELY_RESPONSE",
    "Complaint ID": "COMPLAINT_ID",
}


# ---------------------------------------------------------------------------
# 1. CONNECT
# ---------------------------------------------------------------------------
def get_engine():
    """Create a SQLAlchemy engine for Snowflake from environment variables."""
    try:
        params = dict(
            account=os.environ["SNOWFLAKE_ACCOUNT"],
            user=os.environ["SNOWFLAKE_USER"],
            database=DATABASE,
            schema=SCHEMA,
            warehouse=os.environ.get("SNOWFLAKE_WAREHOUSE", "COMPUTE_WH"),
            role=os.environ.get("SNOWFLAKE_ROLE", "PUBLIC"),
        )
    except KeyError as missing:
        sys.exit(f"Missing environment variable: {missing}")

    authenticator = os.environ.get("SNOWFLAKE_AUTHENTICATOR")
    if authenticator:
        params["authenticator"] = authenticator      # e.g. externalbrowser
    else:
        params["password"] = os.environ.get("SNOWFLAKE_PASSWORD", "")

    return create_engine(URL(**params))


# ---------------------------------------------------------------------------
# 2. EXTRACT
# ---------------------------------------------------------------------------
def extract(csv_path, row_limit):
    """Read the CFPB snapshot. Everything is read as text; types are set in SQL."""
    nrows = row_limit if row_limit and row_limit > 0 else None
    df = pd.read_csv(
        csv_path,
        dtype=str,
        nrows=nrows,
        usecols=lambda col: col in COLUMN_MAP,
        keep_default_na=False,      # keep blanks as "" so cleaning is explicit
    )
    missing = set(COLUMN_MAP) - set(df.columns)
    if missing:
        sys.exit(f"CSV is missing expected columns: {sorted(missing)}")
    print(f"[extract]   read {len(df):,} rows from {csv_path}")
    return df


# ---------------------------------------------------------------------------
# 3. TRANSFORM
# ---------------------------------------------------------------------------
def transform(df):
    """Rename to RAW_COMPLAINTS columns, trim text, drop unusable rows."""
    df = df.rename(columns=COLUMN_MAP)[list(COLUMN_MAP.values())]

    # Trim whitespace in every column; blank strings become NULL.
    df = df.apply(lambda s: s.str.strip())
    df = df.mask(df == "")

    # A complaint without a numeric ID cannot be keyed in the fact table.
    before = len(df)
    df = df[pd.to_numeric(df["COMPLAINT_ID"], errors="coerce").notna()]

    # Keep one row per complaint (the snapshot should already be unique).
    df = df.drop_duplicates(subset="COMPLAINT_ID", keep="first")

    rejected = before - len(df)
    print(f"[transform] kept {len(df):,} rows, rejected {rejected:,}")
    return df, rejected


# ---------------------------------------------------------------------------
# 4. LOAD
# ---------------------------------------------------------------------------
# Set-based SQL that moves staged rows into the 3NF tables. Matches the logic
# in 02_CFPB_3NF_DDL_Schema so the deployed tables are reproduced exactly.
# DELETE (not TRUNCATE) so the script only needs the DELETE privilege that the
# team grants to PUBLIC. Fact table first, then dimensions, then staging.
CLEAR_SQL = [
    "DELETE FROM CONSUMER_COMPLAINTS",
    "DELETE FROM FINANCIAL_COMPANIES",
    "DELETE FROM FINANCIAL_PRODUCTS",
    "DELETE FROM GRIEVANCE_ISSUES",
    "DELETE FROM GEOGRAPHIC_LOCATIONS",
    "DELETE FROM RAW_COMPLAINTS",
]

POPULATE_SQL = [
    # Companies: one row per distinct, trimmed company name
    """
    INSERT INTO FINANCIAL_COMPANIES (company_name)
    SELECT DISTINCT TRIM(company)
    FROM RAW_COMPLAINTS
    WHERE company IS NOT NULL AND TRIM(company) != ''
    """,
    # Products: product / sub-product pairs
    """
    INSERT INTO FINANCIAL_PRODUCTS (product_name, sub_product_name)
    SELECT DISTINCT TRIM(product), COALESCE(NULLIF(TRIM(sub_product), ''), 'N/A')
    FROM RAW_COMPLAINTS
    WHERE product IS NOT NULL AND TRIM(product) != ''
    """,
    # Issues: issue / sub-issue pairs
    """
    INSERT INTO GRIEVANCE_ISSUES (issue_name, sub_issue_name)
    SELECT DISTINCT TRIM(issue), COALESCE(NULLIF(TRIM(sub_issue), ''), 'N/A')
    FROM RAW_COMPLAINTS
    WHERE issue IS NOT NULL AND TRIM(issue) != ''
    """,
    # Locations: state / ZIP pairs, with placeholders for blanks
    """
    INSERT INTO GEOGRAPHIC_LOCATIONS (state_code, zip_code)
    SELECT DISTINCT
        LEFT(COALESCE(NULLIF(TRIM(state), ''), 'UNKNOWN'), 10),
        LEFT(COALESCE(NULLIF(TRIM(zip_code), ''), '00000'), 10)
    FROM RAW_COMPLAINTS
    """,
    # Fact table: look up each surrogate key from its dimension
    """
    INSERT INTO CONSUMER_COMPLAINTS (
        complaint_id, date_received, date_sent_to_company,
        company_id, product_id, issue_id, location_id,
        submitted_via, company_response, timely_response,
        consumer_disputed, consumer_consent)
    SELECT
        TRY_CAST(r.complaint_id AS INT),
        TRY_TO_DATE(r.date_received, 'YYYY-MM-DD'),
        TRY_TO_DATE(r.date_sent_to_company, 'YYYY-MM-DD'),
        c.company_id, p.product_id, i.issue_id, l.location_id,
        COALESCE(NULLIF(TRIM(r.submitted_via), ''), 'Unknown'),
        COALESCE(NULLIF(TRIM(r.company_response_to_consumer), ''), 'In Progress'),
        COALESCE(NULLIF(TRIM(r.timely_response), ''), 'Yes'),
        'N/A',
        'N/A'
    FROM RAW_COMPLAINTS r
    LEFT JOIN FINANCIAL_COMPANIES c
           ON TRIM(r.company) = c.company_name
    LEFT JOIN FINANCIAL_PRODUCTS p
           ON TRIM(r.product) = p.product_name
          AND COALESCE(NULLIF(TRIM(r.sub_product), ''), 'N/A') = p.sub_product_name
    LEFT JOIN GRIEVANCE_ISSUES i
           ON TRIM(r.issue) = i.issue_name
          AND COALESCE(NULLIF(TRIM(r.sub_issue), ''), 'N/A') = i.sub_issue_name
    LEFT JOIN GEOGRAPHIC_LOCATIONS l
           ON LEFT(COALESCE(NULLIF(TRIM(r.state), ''), 'UNKNOWN'), 10) = l.state_code
          AND LEFT(COALESCE(NULLIF(TRIM(r.zip_code), ''), '00000'), 10) = l.zip_code
    WHERE TRY_CAST(r.complaint_id AS INT) IS NOT NULL
    """,
]


def load(engine, df):
    """Stage the DataFrame, then populate the 3NF tables in one transaction."""
    with engine.begin() as conn:
        conn.execute(text(f"USE SCHEMA {DATABASE}.{SCHEMA}"))
        for stmt in CLEAR_SQL:                       # makes reruns idempotent
            conn.execute(text(stmt))

    # to_sql with multi-row INSERTs: needs only the INSERT privilege (a staged
    # bulk load would also need CREATE STAGE, which PUBLIC does not have).
    # The table name is lower case so SQLAlchemy matches the existing
    # RAW_COMPLAINTS table; column names are lower case for the same reason.
    df.rename(columns=str.lower).to_sql(
        "raw_complaints",
        engine,
        if_exists="append",
        index=False,
        method="multi",
        chunksize=1_000,
    )
    print(f"[load]      staged {len(df):,} rows in RAW_COMPLAINTS")

    with engine.begin() as conn:
        for stmt in POPULATE_SQL:
            conn.execute(text(stmt))
    print("[load]      populated the 3NF dimension and fact tables")


# ---------------------------------------------------------------------------
# 5. VERIFY
# ---------------------------------------------------------------------------
def verify(engine, rejected_in_python):
    """Print row counts and record the batch in COMPLAINT_DQA_AUDIT."""
    tables = [
        "RAW_COMPLAINTS", "CONSUMER_COMPLAINTS", "FINANCIAL_COMPANIES",
        "FINANCIAL_PRODUCTS", "GRIEVANCE_ISSUES", "GEOGRAPHIC_LOCATIONS",
    ]
    union = " UNION ALL ".join(
        f"SELECT '{t}' AS table_name, COUNT(*) AS row_count FROM {t}" for t in tables
    )
    with engine.begin() as conn:
        counts = pd.read_sql(text(union), conn)
        print("\n[verify]    row counts")
        print(counts.to_string(index=False))

        n = dict(zip(counts["table_name"].str.upper(), counts["row_count"]))
        ingested = int(n["CONSUMER_COMPLAINTS"])
        rejected = int(rejected_in_python + n["RAW_COMPLAINTS"] - ingested)

        # Orphan check: Snowflake does not enforce FKs, so check them here.
        orphans = conn.execute(text("""
            SELECT COUNT_IF(company_id IS NULL), COUNT_IF(product_id IS NULL),
                   COUNT_IF(issue_id IS NULL),   COUNT_IF(location_id IS NULL)
            FROM CONSUMER_COMPLAINTS
        """)).fetchone()
        print(f"\n[verify]    complaints missing company/product/issue/location key: "
              f"{tuple(int(x) for x in orphans)}")

        batch_id = f"CFPB_LOAD_{uuid.uuid4().hex[:8].upper()}"
        conn.execute(
            text("""
                INSERT INTO COMPLAINT_DQA_AUDIT (batch_id, records_ingested, records_rejected)
                VALUES (:b, :i, :r)
            """),
            {"b": batch_id, "i": ingested, "r": rejected},
        )
        print(f"[verify]    logged {batch_id}: {ingested:,} ingested, {rejected:,} rejected")

    if n["CONSUMER_COMPLAINTS"] < 10_000:
        print("WARNING: fewer than 10,000 complaints loaded (Milestone 2 needs 10K+).")


def main():
    parser = argparse.ArgumentParser(description="Load CFPB complaints into Snowflake.")
    parser.add_argument("csv_path", help="Path to the frozen complaints.csv snapshot")
    parser.add_argument("--rows", type=int, default=10_000,
                        help="Rows to load (default 10000; 0 = whole file)")
    args = parser.parse_args()

    engine = get_engine()                                   # 1. CONNECT
    try:
        raw = extract(args.csv_path, args.rows)             # 2. EXTRACT
        clean, rejected = transform(raw)                    # 3. TRANSFORM
        load(engine, clean)                                 # 4. LOAD
        verify(engine, rejected)                            # 5. VERIFY
    finally:
        engine.dispose()


if __name__ == "__main__":
    main()
