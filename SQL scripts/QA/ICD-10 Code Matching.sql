-- QA: ICD-10 Code Matching

SELECT
    COUNT(*) AS total_claims,

    SUM(
        CASE
            WHEN r.diagnosis_code IS NOT NULL THEN 1
            ELSE 0
        END
    ) AS matched_claims,

    SUM(
        CASE
            WHEN r.diagnosis_code IS NULL THEN 1
            ELSE 0
        END
    ) AS unmatched_claims,

    ROUND(
        100.0 * SUM(
            CASE
                WHEN r.diagnosis_code IS NOT NULL THEN 1
                ELSE 0
            END
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS icd10_match_rate
FROM gold.fact_claims c
LEFT JOIN gold.dim_diagnosis r
    ON c.diagnosis_code = r.diagnosis_code;
