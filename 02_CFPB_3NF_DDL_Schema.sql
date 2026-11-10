-- =====================================================================
-- CFPB COMPLAINT ANALYTICS: 3NF RELATIONAL SCHEMA & DEPLOYMENT (DDL)
-- Database: CFPB_CAPSTONE_DB
-- Schema:   CFPB_SCHEMA
-- Group:    8
-- Description: Milestone 2 3NF Relational Schema Definition with explicit
--              Primary, Foreign, and Composite Natural Unique Constraints,
--              plus staging-to-fact data population logic.
-- =====================================================================

USE DATABASE CFPB_CAPSTONE_DB;
USE SCHEMA CFPB_SCHEMA;

-- =====================================================================
-- 1. DDL: 3NF RELATIONAL SCHEMA DEFINITIONS
-- =====================================================================

-- 1. Financial Companies Dimension
CREATE TABLE IF NOT EXISTS FINANCIAL_COMPANIES (
    company_id INT AUTOINCREMENT PRIMARY KEY,
    company_name VARCHAR(255) NOT NULL UNIQUE
);

-- 2. Financial Products Dimension (Composite Natural Key: product + sub_product)
CREATE TABLE IF NOT EXISTS FINANCIAL_PRODUCTS (
    product_id INT AUTOINCREMENT PRIMARY KEY,
    product_name VARCHAR(255) NOT NULL,
    sub_product_name VARCHAR(255) DEFAULT 'N/A',
    CONSTRAINT uq_product_subproduct UNIQUE (product_name, sub_product_name)
);

-- 3. Grievance Issues Dimension (Composite Natural Key: issue + sub_issue)
CREATE TABLE IF NOT EXISTS GRIEVANCE_ISSUES (
    issue_id INT AUTOINCREMENT PRIMARY KEY,
    issue_name VARCHAR(255) NOT NULL,
    sub_issue_name VARCHAR(255) DEFAULT 'N/A',
    CONSTRAINT uq_issue_subissue UNIQUE (issue_name, sub_issue_name)
);

-- 4. Geographic Locations Dimension (Composite Natural Key: state + zip)
-- Enforces composite unique natural key per Milestone 2 feedback.
CREATE TABLE IF NOT EXISTS GEOGRAPHIC_LOCATIONS (
    location_id INT AUTOINCREMENT PRIMARY KEY,
    state_code VARCHAR(10) DEFAULT 'UNKNOWN',
    zip_code VARCHAR(20) DEFAULT '00000',
    CONSTRAINT uq_state_zip UNIQUE (state_code, zip_code)
);

-- 5. Fact Table: Consumer Complaints
CREATE TABLE IF NOT EXISTS CONSUMER_COMPLAINTS (
    complaint_id BIGINT PRIMARY KEY,
    date_received DATE,
    date_sent_to_company DATE,
    company_id INT,
    product_id INT,
    issue_id INT,
    location_id INT,
    submitted_via VARCHAR(100),
    company_response VARCHAR(255),
    timely_response VARCHAR(10),
    consumer_disputed VARCHAR(10),
    consumer_consent VARCHAR(100),
    FOREIGN KEY (company_id) REFERENCES FINANCIAL_COMPANIES(company_id),
    FOREIGN KEY (product_id) REFERENCES FINANCIAL_PRODUCTS(product_id),
    FOREIGN KEY (issue_id) REFERENCES GRIEVANCE_ISSUES(issue_id),
    FOREIGN KEY (location_id) REFERENCES GEOGRAPHIC_LOCATIONS(location_id)
);

-- 6. Audit Table: Data Quality Assessment Audit Log
CREATE TABLE IF NOT EXISTS COMPLAINT_DQA_AUDIT (
    audit_id INT AUTOINCREMENT PRIMARY KEY,
    batch_id VARCHAR(100),
    records_ingested INT,
    records_rejected INT,
    load_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
);


-- =====================================================================
-- 2. DML: 3NF DATA TRANSFORMATION & INGESTION (FROM RAW_COMPLAINTS)
-- =====================================================================

-- 1. Truncate 3NF tables to ensure clean reload
TRUNCATE TABLE IF EXISTS CONSUMER_COMPLAINTS;
TRUNCATE TABLE IF EXISTS FINANCIAL_COMPANIES;
TRUNCATE TABLE IF EXISTS FINANCIAL_PRODUCTS;
TRUNCATE TABLE IF EXISTS GRIEVANCE_ISSUES;
TRUNCATE TABLE IF EXISTS GEOGRAPHIC_LOCATIONS;

-- 2. Populate Financial Companies Dimension
INSERT INTO FINANCIAL_COMPANIES (company_name)
SELECT DISTINCT TRIM(company)
FROM RAW_COMPLAINTS
WHERE company IS NOT NULL AND TRIM(company) != '';

-- 3. Populate Financial Products & Sub-products Dimension
INSERT INTO FINANCIAL_PRODUCTS (product_name, sub_product_name)
SELECT DISTINCT 
    TRIM(product),
    COALESCE(NULLIF(TRIM(sub_product), ''), 'N/A')
FROM RAW_COMPLAINTS
WHERE product IS NOT NULL AND TRIM(product) != '';

-- 4. Populate Grievance Issues & Sub-issues Dimension
INSERT INTO GRIEVANCE_ISSUES (issue_name, sub_issue_name)
SELECT DISTINCT 
    TRIM(issue),
    COALESCE(NULLIF(TRIM(sub_issue), ''), 'N/A')
FROM RAW_COMPLAINTS
WHERE issue IS NOT NULL AND TRIM(issue) != '';

-- 5. Populate Geographic Locations Dimension
INSERT INTO GEOGRAPHIC_LOCATIONS (state_code, zip_code)
SELECT DISTINCT 
    LEFT(COALESCE(NULLIF(TRIM(state), ''), 'UNKNOWN'), 10),
    LEFT(COALESCE(NULLIF(TRIM(zip_code), ''), '00000'), 10)
FROM RAW_COMPLAINTS;

-- 6. Map and Load Consumer Complaints Fact Table
INSERT INTO CONSUMER_COMPLAINTS (
    complaint_id,
    date_received,
    date_sent_to_company,
    company_id,
    product_id,
    issue_id,
    location_id,
    submitted_via,
    company_response_to_consumer,
    timely_response,
    consumer_disputed,
    consumer_consent_provided
)
SELECT
    TRY_CAST(r.complaint_id AS BIGINT),
    TRY_TO_DATE(r.date_received, 'YYYY-MM-DD'),
    TRY_TO_DATE(r.date_sent_to_company, 'YYYY-MM-DD'),
    c.company_id,
    p.product_id,
    i.issue_id,
    l.location_id,
    COALESCE(NULLIF(TRIM(r.submitted_via), ''), 'Unknown'),
    COALESCE(NULLIF(TRIM(r.company_response_to_consumer), ''), 'In Progress'),
    COALESCE(NULLIF(TRIM(r.timely_response), ''), 'Yes'),
    'N/A',
    'N/A'
FROM RAW_COMPLAINTS r
LEFT JOIN FINANCIAL_COMPANIES c ON TRIM(r.company) = c.company_name
LEFT JOIN FINANCIAL_PRODUCTS p ON TRIM(r.product) = p.product_name
    AND COALESCE(NULLIF(TRIM(r.sub_product), ''), 'N/A') = p.sub_product_name
LEFT JOIN GRIEVANCE_ISSUES i ON TRIM(r.issue) = i.issue_name
    AND COALESCE(NULLIF(TRIM(r.sub_issue), ''), 'N/A') = i.sub_issue_name
LEFT JOIN GEOGRAPHIC_LOCATIONS l ON LEFT(COALESCE(NULLIF(TRIM(r.state), ''), 'UNKNOWN'), 10) = l.state_code
    AND LEFT(COALESCE(NULLIF(TRIM(r.zip_code), ''), '00000'), 10) = l.zip_code
WHERE TRY_CAST(r.complaint_id AS BIGINT) IS NOT NULL;
