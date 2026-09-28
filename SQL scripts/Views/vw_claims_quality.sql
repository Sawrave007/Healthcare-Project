CREATE OR REPLACE VIEW gold.vw_claim_quality AS

SELECT
    COUNT(*) AS total_claims,

    SUM(
        CASE
            WHEN claim_status <> outcome THEN 1
            ELSE 0
        END
    ) AS status_outcome_mismatches,

    ROUND(
        100.0 * SUM(
            CASE
                WHEN claim_status <> outcome THEN 1
                ELSE 0
            END
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS mismatch_rate,

    SUM(
        CASE
            WHEN diagnosis_code IS NULL THEN 1
            ELSE 0
        END
    ) AS missing_diagnosis_codes,

    SUM(
        CASE
            WHEN procedure_code IS NULL THEN 1
            ELSE 0
        END
    ) AS missing_procedure_codes

FROM gold.fact_claims;


select * from gold.vw_claim_quality
