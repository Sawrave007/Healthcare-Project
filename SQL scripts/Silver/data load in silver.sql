CREATE OR REPLACE PROCEDURE silver.load_silver()
LANGUAGE plpgsql
AS $$
BEGIN

    -- ========================================================
    -- 0. CLEAR SILVER TABLES
    -- ========================================================
    -- Clear child/dependent tables first.
    -- This allows the Silver layer to be rebuilt from Bronze
    -- from a clean state every time the procedure runs.
    -- ========================================================

    TRUNCATE TABLE
        silver.claims_exceptions,
        silver.claims,
        silver.icd10_matched,
        silver.icd10_unmatched,
        silver.cpt_hcpcs,
        silver.icd10
    RESTART IDENTITY;


    -- ========================================================
    -- 1. INSERT ICD-10 REFERENCE DATA
    -- ========================================================

    INSERT INTO silver.icd10 (
        diagnosis_code,
        description
    )
    SELECT
        TRIM(UPPER(r.diagnosis_code)),
        TRIM(r.description)
    FROM bronze.icd10_raw r;


    -- ========================================================
    -- 2. INSERT CPT / HCPCS REFERENCE DATA
    -- ========================================================

    INSERT INTO silver.cpt_hcpcs (
        procedure_code,
        description
    )
    SELECT DISTINCT
        TRIM(UPPER(r."HCPCS_Cd"::text)),
        TRIM(r."HCPCS_Desc"::text)
    FROM bronze.cpt_hcpcs_raw r;


    -- ========================================================
    -- 3. INSERT CLEANED CLAIMS
    -- ========================================================

    INSERT INTO silver.claims (
        claim_id,
        provider_id,
        patient_id,
        date_of_service,
        billed_amount,
        procedure_code,
        diagnosis_code,
        is_valid_diagnosis,
        allowed_amount,
        paid_amount,
        insurance_type,
        claim_status,
        reason_code,
        follow_up_required,
        ar_status,
        outcome
    )
    SELECT
        TRIM(r."Claim ID"::text),

        TRIM(r."Provider ID"::text),

        TRIM(r."Patient ID"::text),

        r."Date of Service"::date,

        r."Billed Amount"::numeric,

        TRIM(UPPER(r."Procedure_Code"::text)),

        TRIM(UPPER(r."Diagnosis Code"::text)),

        EXISTS (
            SELECT 1
            FROM silver.icd10 d
            WHERE d.diagnosis_code =
                  TRIM(UPPER(r."Diagnosis Code"::text))
        ),

        r."Allowed Amount"::numeric,

        r."Paid Amount"::numeric,

        TRIM(r."Insurance Type"::text),

        TRIM(r."Claim Status"::text),

        NULLIF(TRIM(r."Reason Code"::text), ''),

        TRIM(r."Follow-up Required"::text) = 'Yes',

        TRIM(r."AR Status"::text),

        TRIM(r."Outcome"::text)

    FROM bronze.claims_raw r;


    -- ========================================================
    -- 4. INSERT MATCHED ICD-10 CODES
    -- ========================================================
    -- Only codes that:
    --   1. Exist in silver.icd10
    --   2. Are used by at least one claim
    --
    -- Chapter/category remain NULL for now.
    -- ========================================================

    INSERT INTO silver.icd10_matched (
        diagnosis_code,
        description
    )
    SELECT
        i.diagnosis_code,
        i.description
    FROM silver.icd10 i
    INNER JOIN (
        SELECT DISTINCT
            diagnosis_code
        FROM silver.claims
    ) c
        ON i.diagnosis_code = c.diagnosis_code;


    -- ========================================================
    -- 5. INSERT UNMATCHED ICD-10 CODES
    -- ========================================================
    -- Codes used in claims but not found in silver.icd10.
    -- One row per unique unmatched code.
    -- ========================================================

    INSERT INTO silver.icd10_unmatched (
        diagnosis_code,
        claim_count,
        likely_reason,
        category
    )
    SELECT
        c.diagnosis_code,

        COUNT(*) AS claim_count,

        CASE
            WHEN LEFT(c.diagnosis_code, 3) = 'A16'
                THEN 'Code family retired, no A16.* codes exist in current ICD-10-CM'

            WHEN LEFT(c.diagnosis_code, 3) = 'A09'
                THEN 'A09 has no decimal subdivisions'

            ELSE
                'Needs additional digit(s) for full specificity, or an invalid combination — verify individually'
        END AS likely_reason,

        NULL AS category

    FROM silver.claims c

    LEFT JOIN silver.icd10 i
        ON i.diagnosis_code = c.diagnosis_code

    WHERE i.diagnosis_code IS NULL

    GROUP BY c.diagnosis_code;


    -- ========================================================
    -- 6. QA EXCEPTIONS
    -- ========================================================


    -- ========================================================
    -- QA 1: Unmatched ICD-10
    -- ========================================================

    INSERT INTO silver.claims_exceptions (
        claim_id,
        test_name,
        error_type,
        severity,
        failed_value,
        expected_condition
    )
    SELECT
        claim_id,
        'unmapped_icd10',
        'invalid_diagnosis_code',
        'medium',
        diagnosis_code,
        'Diagnosis code should exist in silver.icd10'

    FROM silver.claims

    WHERE is_valid_diagnosis = FALSE;


    -- ========================================================
    -- QA 2: Claim Status vs Outcome
    -- ========================================================

    INSERT INTO silver.claims_exceptions (
        claim_id,
        test_name,
        error_type,
        severity,
        failed_value,
        expected_condition
    )
    SELECT
        claim_id,
        'status_outcome_mismatch',
        'logical_inconsistency',
        'high',
        claim_status || ' / ' || outcome,
        'Claim status and outcome should be consistent'

    FROM silver.claims

    WHERE
           (claim_status = 'Paid'
            AND outcome <> 'Paid')

        OR (claim_status = 'Denied'
            AND outcome <> 'Denied')

        OR (claim_status = 'Under Review'
            AND outcome IN (
                'Paid',
                'Denied',
                'Partially Paid'
            ));


    -- ========================================================
    -- QA 3: AR Status
    -- ========================================================

    INSERT INTO silver.claims_exceptions (
        claim_id,
        test_name,
        error_type,
        severity,
        failed_value,
        expected_condition
    )
    SELECT
        claim_id,
        'ar_status_mismatch',
        'logical_inconsistency',
        'low',
        claim_status || ' / ' || ar_status,
        'Under-review claims should not have Closed AR status'

    FROM silver.claims

    WHERE claim_status = 'Under Review'
      AND ar_status = 'Closed';

-- ========================================================
-- QA 4: Reason code on Paid claim
-- ========================================================

    INSERT INTO silver.claims_exceptions (
        claim_id,
        test_name,
        error_type,
        severity,
        failed_value,
        expected_condition
    )

    SELECT
        claim_id,
        'reason_on_paid_claim',
        'logical_inconsistency',
        'low',
        reason_code,
        'Paid claims should not have a denial/reason code'

    FROM silver.claims

    WHERE claim_status = 'Paid'
    AND reason_code IS NOT NULL;


    -- ========================================================
    -- COMPLETED
    -- ========================================================

END;
$$;

