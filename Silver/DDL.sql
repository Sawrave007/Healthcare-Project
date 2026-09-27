CREATE SCHEMA IF NOT EXISTS silver;

CREATE TABLE silver.icd10 (
    diagnosis_code   text PRIMARY KEY,
    description       text NOT NULL,
    chapter           text,
    category          text
);

CREATE TABLE silver.icd10_unmatched (
    diagnosis_code   text PRIMARY KEY,
    claim_count       integer NOT NULL,  -- how many claims use this code
    likely_reason      text,
    category            text
);

CREATE TABLE silver.cpt_hcpcs (
    procedure_code   text PRIMARY KEY,
    description        text NOT NULL
);

CREATE TABLE silver.claims (
    claim_id             text PRIMARY KEY,
    provider_id          text NOT NULL,
    patient_id           text NOT NULL,
    date_of_service      date,
    billed_amount        numeric(10,2),
    procedure_code       text REFERENCES silver.cpt_hcpcs(procedure_code),
    diagnosis_code       text,
    is_valid_diagnosis   boolean DEFAULT false,
    allowed_amount       numeric(10,2),
    paid_amount           numeric(10,2),
    insurance_type        text,
    claim_status          text,
    reason_code            text,
    follow_up_required     boolean,
    ar_status               text,
    outcome                 text,
    loaded_at               timestamp DEFAULT now()
);

CREATE TABLE silver.claims_exceptions (
    exception_id        bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    claim_id             text NOT NULL REFERENCES silver.claims(claim_id),
    test_name             text NOT NULL,
    error_type             text NOT NULL,
    severity                text NOT NULL CHECK (severity IN ('low','medium','high')),
    failed_value            text,
    expected_condition      text,
    detected_at              timestamp DEFAULT now()
);
