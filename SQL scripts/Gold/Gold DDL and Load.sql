-- ============================================================
-- GOLD LAYER: SCHEMA + POPULATION
-- Grain of gold.fact_claims: one row per claim
-- ============================================================

CREATE SCHEMA IF NOT EXISTS gold;


-- ============================================================
-- DIMENSION TABLES
-- ============================================================

-- ------------------------------------------------------------
-- dim_diagnosis
-- Only ICD-10 codes actually used in claims and successfully
-- ------------------------------------------------------------
CREATE TABLE gold.dim_diagnosis (
    diagnosis_code    text PRIMARY KEY,
    description       text NOT NULL,
    category          text,
    chapter           text
);


-- ------------------------------------------------------------
-- dim_procedure
-- Procedure code + description.
-- ------------------------------------------------------------
CREATE TABLE gold.dim_procedure (
    procedure_code    text PRIMARY KEY,
    description       text NOT NULL
);


-- ------------------------------------------------------------
-- dim_payer
-- Represents the insurance/payer categories available
-- in the claims dataset.
-- ------------------------------------------------------------
CREATE TABLE gold.dim_payer (
    payer_name        text PRIMARY KEY,
    payer_type        text NOT NULL
    -- Government / Commercial / Self-Pay
);


-- ------------------------------------------------------------
-- dim_date
-- Standard calendar dimension.
-- ------------------------------------------------------------
CREATE TABLE gold.dim_date (
    date_key          date PRIMARY KEY,
    year              int NOT NULL,
    quarter           int NOT NULL,
    month             int NOT NULL,
    month_name        text NOT NULL,
    day               int NOT NULL,
    day_of_week       int NOT NULL,
    day_name          text NOT NULL,
    is_weekend        boolean NOT NULL
);


-- ============================================================
-- FACT TABLE
-- ============================================================

-- ------------------------------------------------------------
-- fact_claims
--
-- Grain: one row per claim.
--
-- provider_id / patient_id are kept as attributes rather than
-- separate dimensions because the current dataset does not
-- provide enough repeated entity-level information to justify
-- dim_provider / dim_patient.
--
-- diagnosis_code intentionally has NO FK because some claims
-- contain unmatched diagnosis codes. Those claims must still
-- remain in the fact table for data-quality analysis.
-- ------------------------------------------------------------
CREATE TABLE gold.fact_claims (
    claim_id            text PRIMARY KEY,

    provider_id         text NOT NULL,
    patient_id          text NOT NULL,

    date_of_service     date
        REFERENCES gold.dim_date (date_key),

    procedure_code      text
        REFERENCES gold.dim_procedure (procedure_code),

    diagnosis_code      text,

    is_valid_diagnosis  boolean NOT NULL,

    payer_name          text
        REFERENCES gold.dim_payer (payer_name),

    billed_amount       numeric(10, 2),
    allowed_amount      numeric(10, 2),
    paid_amount         numeric(10, 2),

    claim_status        text,
    reason_code         text,
    follow_up_required  boolean,
    ar_status           text,
    outcome             text
);


-- ============================================================
-- 1. DIM_DATE
-- ============================================================
-- Generate the calendar for 2024.
-- ============================================================

INSERT INTO gold.dim_date (
    date_key,
    year,
    quarter,
    month,
    month_name,
    day,
    day_of_week,
    day_name,
    is_weekend
)
SELECT
    d::date,
    EXTRACT(YEAR FROM d)::int,
    EXTRACT(QUARTER FROM d)::int,
    EXTRACT(MONTH FROM d)::int,
    TRIM(TO_CHAR(d, 'Month')),
    EXTRACT(DAY FROM d)::int,
    EXTRACT(DOW FROM d)::int,
    TRIM(TO_CHAR(d, 'Day')),
    EXTRACT(DOW FROM d) IN (0, 6)
FROM GENERATE_SERIES(
    '2024-01-01'::date,
    '2024-12-31'::date,
    INTERVAL '1 day'
) AS d;


-- ============================================================
-- 2. DIM_PAYER
-- ============================================================

INSERT INTO gold.dim_payer (
    payer_name,
    payer_type
)
VALUES
    ('Medicare',   'Government'),
    ('Medicaid',   'Government'),
    ('Commercial', 'Commercial'),
    ('Self-Pay',   'Self-Pay');


-- ============================================================
-- 3. DIM_PROCEDURE
-- ============================================================

INSERT INTO gold.dim_procedure (
    procedure_code,
    description
)
SELECT
    procedure_code,
    description
FROM silver.cpt_hcpcs;


-- ============================================================
-- 4. DIM_DIAGNOSIS
-- ============================================================


INSERT INTO gold.dim_diagnosis (
    diagnosis_code,
    description,
    category,
    chapter
)
SELECT
    diagnosis_code,
    description,
    category,
    chapter
FROM silver.icd10_matched;


-- ============================================================
-- 5. FACT_CLAIMS
-- ============================================================
-- Grain: one row per claim.
--
-- diagnosis_code is copied even when unmatched.
-- is_valid_diagnosis tells us whether the diagnosis resolved
-- against the reference data.
-- ============================================================

INSERT INTO gold.fact_claims (
    claim_id,
    provider_id,
    patient_id,
    date_of_service,
    procedure_code,
    diagnosis_code,
    is_valid_diagnosis,
    payer_name,
    billed_amount,
    allowed_amount,
    paid_amount,
    claim_status,
    reason_code,
    follow_up_required,
    ar_status,
    outcome
)
SELECT
    claim_id,
    provider_id,
    patient_id,
    date_of_service,
    procedure_code,
    diagnosis_code,
    is_valid_diagnosis,
    insurance_type,
    billed_amount,
    allowed_amount,
    paid_amount,
    claim_status,
    reason_code,
    follow_up_required,
    ar_status,
    outcome
FROM silver.claims;
