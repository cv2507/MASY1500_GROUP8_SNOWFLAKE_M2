USE DATABASE CFPB_CAPSTONE_DB;
USE SCHEMA CFPB_SCHEMA;
-- 1.Financial Companies Table
CREATE TABLE IF NOT EXISTS FINANCIAL_COMPANIES (
    company_id INT AUTOINCREMENT PRIMARY KEY,
    company_name VARCHAR(255) NOT NULL UNIQUE
);
-- 2.Financial Products & Sub-products Table
CREATE TABLE IF NOT EXISTS FINANCIAL_PRODUCTS (
    product_id INT AUTOINCREMENT PRIMARY KEY,
    product_name VARCHAR(255) NOT NULL,
    sub_product_name VARCHAR(255) DEFAULT 'N/A'
);
-- 3.Grievance Issues & Sub-issues Table
CREATE TABLE IF NOT EXISTS GRIEVANCE_ISSUES (
    issue_id INT AUTOINCREMENT PRIMARY KEY,
    issue_name VARCHAR(255) NOT NULL,
    sub_issue_name VARCHAR(255) DEFAULT 'N/A'
);
-- 4.Geographic Locations Table
CREATE TABLE IF NOT EXISTS GEOGRAPHIC_LOCATIONS (
    location_id INT AUTOINCREMENT PRIMARY KEY,
    state_code VARCHAR(10) DEFAULT 'UNKNOWN',
    zip_code VARCHAR(20) DEFAULT '00000'
);
-- 5. Fact Table: Consumer Complaints
CREATE TABLE IF NOT EXISTS CONSUMER_COMPLAINTS (
    complaint_id BIGINT PRIMARY KEY,
    date_received DATE,
    date_sent_to_company DATE,
    company_id INT FOREIGN KEY REFERENCES FINANCIAL_COMPANIES(company_id),
    product_id INT FOREIGN KEY REFERENCES FINANCIAL_PRODUCTS(product_id),
    issue_id INT FOREIGN KEY REFERENCES GRIEVANCE_ISSUES(issue_id),
    location_id INT FOREIGN KEY REFERENCES GEOGRAPHIC_LOCATIONS(location_id),
    submitted_via VARCHAR(100),
    company_response VARCHAR(255),
    timely_response VARCHAR(10),
    consumer_disputed VARCHAR(10),
    consumer_consent VARCHAR(100)
);
-- 6. Audit Table: Data Quality Assessment Audit Log
CREATE TABLE IF NOT EXISTS COMPLAINT_DQA_AUDIT (
    audit_id INT AUTOINCREMENT PRIMARY KEY,
    batch_id VARCHAR(100),
    records_ingested INT,
    records_rejected INT,
    load_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
);
CFPB_CAPSTONE_DBCFPB_CAPSTONE_DBCFPB_CAPSTONE_DB.CFPB_SCHEMA.RAW_COMPLAINTSCFPB_CAPSTONE_DB.CFPB_SCHEMA.RAW_COMPLAINTSCFPB_CAPSTONE_DB.CFPB_SCHEMA.RAW_COMPLAINTS
SELECT
    COUNT(*)
FROM
    RAW_COMPLAINTS;
    --2. Create raw complaint table
    CFPB_CAPSTONE_DBCFPB_CAPSTONE_DBCFPB_CAPSTONE_DB.CFPB_SCHEMA.RAW_COMPLAINTSCREATE TABLE RAW_COMPLAINTS (
        date_received VARCHAR,
        product VARCHAR,
        sub_product VARCHAR,
        issue VARCHAR,
        sub_issue VARCHAR,
        company_public_response VARCHAR,
        company VARCHAR,
        state VARCHAR,
        zip_code VARCHAR,
        tags VARCHAR,
        submitted_via VARCHAR,
        date_sent_to_company VARCHAR,
        company_response_to_consumer VARCHAR,
        timely_response VARCHAR,
        complaint_id VARCHAR
    );
SELECT
    COUNT(*) AS total_raw_rows
FROM
    RAW_COMPLAINTS;
    -- 1. Truncate 3NF tables to ensure a clean load
    TRUNCATE TABLE CONSUMER_COMPLAINTS;
TRUNCATE TABLE FINANCIAL_COMPANIES;
TRUNCATE TABLE FINANCIAL_PRODUCTS;
TRUNCATE TABLE GRIEVANCE_ISSUES;
TRUNCATE TABLE GEOGRAPHIC_LOCATIONS;
    -- 2. Populate Companies
INSERT INTO
    FINANCIAL_COMPANIES (company_name)
SELECT
    DISTINCT TRIM(company)
FROM
    RAW_COMPLAINTS
WHERE
    company IS NOT NULL
    AND TRIM(company) != '';
    -- 3. Insert unique products & sub-products
INSERT INTO
    FINANCIAL_PRODUCTS (product_name, sub_product_name)
SELECT
    DISTINCT TRIM(product),
    COALESCE(NULLIF(TRIM(sub_product), ''), 'N/A')
FROM
    RAW_COMPLAINTS
WHERE
    product IS NOT NULL
    AND TRIM(product) != '';
    -- 4. Insert unique grievance issues & sub-issues
INSERT INTO
    GRIEVANCE_ISSUES (issue_name, sub_issue_name)
SELECT
    DISTINCT TRIM(issue),
    COALESCE(NULLIF(TRIM(sub_issue), ''), 'N/A')
FROM
    RAW_COMPLAINTS
WHERE
    issue IS NOT NULL
    AND TRIM(issue) != '';
    -- 5. Insert unique geographic locations
INSERT INTO
    GEOGRAPHIC_LOCATIONS (state_code, zip_code)
SELECT
    DISTINCT LEFT(COALESCE(NULLIF(TRIM(state), ''), 'UNKNOWN'), 10),
    LEFT(
        COALESCE(NULLIF(TRIM(zip_code), ''), '00000'),
        10
    )
FROM
    RAW_COMPLAINTS;
    -- 6. Map and load consumer complaints fact table
INSERT INTO
    CONSUMER_COMPLAINTS (
        complaint_id,
        date_received,
        date_sent_to_company,
        company_id,
        product_id,
        issue_id,
        location_id,
        submitted_via,
        company_response,
        timely_response,
        consumer_disputed,
        consumer_consent
    )
SELECT
    TRY_CAST(r.complaint_id AS INT),
    TRY_TO_DATE(r.date_received, 'YYYY-MM-DD'),
    TRY_TO_DATE(r.date_sent_to_company, 'YYYY-MM-DD'),
    c.company_id,
    p.product_id,
    i.issue_id,
    l.location_id,
    COALESCE(NULLIF(TRIM(r.submitted_via), ''), 'Unknown'),
    COALESCE(
        NULLIF(TRIM(r.company_response_to_consumer), ''),
        'In Progress'
    ),
    COALESCE(NULLIF(TRIM(r.timely_response), ''), 'Yes'),
    'N/A',
    'N/A'
FROM
    RAW_COMPLAINTS r
    LEFT JOIN FINANCIAL_COMPANIES c ON TRIM(r.company) = c.company_name
    LEFT JOIN FINANCIAL_PRODUCTS p ON TRIM(r.product) = p.product_name
    AND COALESCE(NULLIF(TRIM(r.sub_product), ''), 'N/A') = p.sub_product_name
    LEFT JOIN GRIEVANCE_ISSUES i ON TRIM(r.issue) = i.issue_name
    AND COALESCE(NULLIF(TRIM(r.sub_issue), ''), 'N/A') = i.sub_issue_name
    LEFT JOIN GEOGRAPHIC_LOCATIONS l ON LEFT(
        COALESCE(NULLIF(TRIM(r.state), ''), 'UNKNOWN'),
        10
    ) = l.state_code
    AND LEFT(
        COALESCE(NULLIF(TRIM(r.zip_code), ''), '00000'),
        10
    ) = l.zip_code
WHERE
    TRY_CAST(r.complaint_id AS INT) IS NOT NULL;
    --final row count
SELECT
    'RAW_COMPLAINTS' AS table_name,
    COUNT(*) AS row_count
FROM
    RAW_COMPLAINTS
UNION ALL
SELECT
    'CONSUMER_COMPLAINTS',
    COUNT(*)
FROM
    CONSUMER_COMPLAINTS
UNION ALL
SELECT
    'FINANCIAL_COMPANIES',
    COUNT(*)
FROM
    FINANCIAL_COMPANIES
UNION ALL
SELECT
    'FINANCIAL_PRODUCTS',
    COUNT(*)
FROM
    FINANCIAL_PRODUCTS
UNION ALL
SELECT
    'GRIEVANCE_ISSUES',
    COUNT(*)
FROM
    GRIEVANCE_ISSUES
UNION ALL
SELECT
    'GEOGRAPHIC_LOCATIONS',
    COUNT(*)
FROM
    GEOGRAPHIC_LOCATIONS;
    --Verify Data and Table
SELECT
    COUNT(DISTINCT TRIM(company)) AS unique_company_count
FROM
    RAW_COMPLAINTS
WHERE
    company IS NOT NULL
    AND TRIM(company) != '';
SELECT
    COUNT(*) AS unique_product_count
FROM
    (
        SELECT
            DISTINCT TRIM(product) AS product_name,
            COALESCE(NULLIF(TRIM(sub_product), ''), 'N/A') AS sub_product_name
        FROM
            RAW_COMPLAINTS
        WHERE
            product IS NOT NULL
            AND TRIM(product) != ''
    );
SELECT
    COUNT(*) AS unique_issue_count
FROM
    (
        SELECT
            DISTINCT TRIM(issue) AS issue_name,
            COALESCE(NULLIF(TRIM(sub_issue), ''), 'N/A') AS sub_issue_name
        FROM
            RAW_COMPLAINTS
        WHERE
            issue IS NOT NULL
            AND TRIM(issue) != ''
    );
SELECT
    COUNT(*) AS unique_location_count
FROM
    (
        SELECT
            DISTINCT LEFT(COALESCE(NULLIF(TRIM(state), ''), 'UNKNOWN'), 10) AS state_code,
            LEFT(
                COALESCE(NULLIF(TRIM(zip_code), ''), '00000'),
                10
            ) AS zip_code
        FROM
            RAW_COMPLAINTS
    );
SELECT
    COUNT(*) AS total_raw_records,
    COUNT(TRY_CAST(r.complaint_id AS INT)) AS valid_complaint_ids,
    COUNT(c.company_id) AS matched_companies,
    COUNT(p.product_id) AS matched_products,
    COUNT(i.issue_id) AS matched_issues,
    COUNT(l.location_id) AS matched_locations
FROM
    RAW_COMPLAINTS r
    LEFT JOIN FINANCIAL_COMPANIES c ON TRIM(r.company) = c.company_name
    LEFT JOIN FINANCIAL_PRODUCTS p ON TRIM(r.product) = p.product_name
    AND COALESCE(NULLIF(TRIM(r.sub_product), ''), 'N/A') = p.sub_product_name
    LEFT JOIN GRIEVANCE_ISSUES i ON TRIM(r.issue) = i.issue_name
    AND COALESCE(NULLIF(TRIM(r.sub_issue), ''), 'N/A') = i.sub_issue_name
    LEFT JOIN GEOGRAPHIC_LOCATIONS l ON LEFT(
        COALESCE(NULLIF(TRIM(r.state), ''), 'UNKNOWN'),
        10
    ) = l.state_code
    AND LEFT(
        COALESCE(NULLIF(TRIM(r.zip_code), ''), '00000'),
        10
    ) = l.zip_code;
SELECT
    COUNT(*)
FROM
    RAW_COMPLAINTS;
SELECT
    COUNT(*) AS total_locations_in_table
FROM
    GEOGRAPHIC_LOCATIONS;
SELECT
    COUNT(*) AS unique_raw_locations
FROM
    (
        SELECT
            DISTINCT LEFT(COALESCE(NULLIF(TRIM(state), ''), 'UNKNOWN'), 10) AS state_code,
            LEFT(
                COALESCE(NULLIF(TRIM(zip_code), ''), '00000'),
                10
            ) AS zip_code
        FROM
            RAW_COMPLAINTS
    );
-- check for duplicate
SELECT
    company_name,
    COUNT(*) AS duplicate_count
FROM
    FINANCIAL_COMPANIES
GROUP BY
    company_name
HAVING
    COUNT(*) > 1;
SELECT
    product_name,
    sub_product_name,
    COUNT(*) AS duplicate_count
FROM
    FINANCIAL_PRODUCTS
GROUP BY
    product_name,
    sub_product_name
HAVING
    COUNT(*) > 1;
SELECT
    issue_name,
    sub_issue_name,
    COUNT(*) AS duplicate_count
FROM
    GRIEVANCE_ISSUES
GROUP BY
    issue_name,
    sub_issue_name
HAVING
    COUNT(*) > 1;
SELECT
    state_code,
    zip_code,
    COUNT(*) AS duplicate_count
FROM
    GEOGRAPHIC_LOCATIONS
GROUP BY
    state_code,
    zip_code
HAVING
    COUNT(*) > 1;
SELECT
    complaint_id,
    COUNT(*) AS duplicate_count
FROM
    CONSUMER_COMPLAINTS
GROUP BY
    complaint_id
HAVING
    COUNT(*) > 1;
SELECT
    complaint_id,
    COUNT(*) AS duplicate_count
FROM
    RAW_COMPLAINTS
GROUP BY
    complaint_id
HAVING
    COUNT(*) > 1;
SELECT
    COUNT(*) AS total_rows_in_consumer_complaints
FROM
    CONSUMER_COMPLAINTS;
SELECT
    COUNT(*) AS total_rows_in_GEOGRAPHIC_LOCATIONS
FROM
    GEOGRAPHIC_LOCATIONS;
CFPB_CAPSTONE_DB.INFORMATION_SCHEMACFPB_CAPSTONE_DB.CFPB_SCHEMACFPB_CAPSTONE_DB.CFPB_SCHEMA.CONSUMER_COMPLAINTS
