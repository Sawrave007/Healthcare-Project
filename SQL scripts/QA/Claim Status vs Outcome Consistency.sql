-- QA: Claim Status vs Outcome Consistency
-- Official payment/denial KPIs use outcome, not claim_status.

-- Overall mismatch rate
SELECT
    COUNT(*) AS total_claims,
    SUM(
        CASE
            WHEN claim_status <> outcome THEN 1
            ELSE 0
        END
    ) AS mismatch_claims,
    ROUND(
        100.0 * SUM(
            CASE
                WHEN claim_status <> outcome THEN 1
                ELSE 0
            END
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS mismatch_rate
FROM gold.fact_claims;


-- Where the mismatches occur
SELECT
    claim_status,
    outcome,
    COUNT(*) AS claim_count
FROM gold.fact_claims
WHERE claim_status <> outcome
GROUP BY claim_status, outcome
ORDER BY claim_count DESC;
