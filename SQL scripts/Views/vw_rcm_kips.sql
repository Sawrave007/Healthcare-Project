CREATE OR REPLACE VIEW gold.vw_rcm_kpis AS

SELECT

    -- Claim volume
    COUNT(*) AS total_claims,

    SUM(CASE WHEN outcome = 'Paid' THEN 1 ELSE 0 END)
        AS paid_claims,

    SUM(CASE WHEN outcome = 'Partially Paid' THEN 1 ELSE 0 END)
        AS partially_paid_claims,

    SUM(CASE WHEN outcome = 'Denied' THEN 1 ELSE 0 END)
        AS denied_claims,


    -- Claim rates
    ROUND(
        100.0 * SUM(CASE WHEN outcome = 'Paid' THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0),
        2
    ) AS paid_rate,

    ROUND(
        100.0 * SUM(CASE WHEN outcome = 'Partially Paid' THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0),
        2
    ) AS partial_payment_rate,

    ROUND(
        100.0 * SUM(CASE WHEN outcome = 'Denied' THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0),
        2
    ) AS denial_rate,


    -- Financial KPIs
    SUM(billed_amount) AS total_billed,

    SUM(allowed_amount) AS total_allowed,

    SUM(paid_amount) AS total_paid,

    AVG(paid_amount) AS average_paid_per_claim,

    SUM(
        CASE
            WHEN outcome = 'Denied'
            THEN billed_amount
            ELSE 0
        END
    ) AS denied_billed_amount

FROM gold.fact_claims;

select * from gold.vw_rcm_kpis



------------------------------------------------------------------------------


CREATE OR REPLACE VIEW gold.vw_rcm_kpis_is_valid AS

SELECT

    -- Claim volume
    COUNT(*) AS total_claims,

    SUM(CASE WHEN outcome = 'Paid' THEN 1 ELSE 0 END)
        AS paid_claims,

    SUM(CASE WHEN outcome = 'Partially Paid' THEN 1 ELSE 0 END)
        AS partially_paid_claims,

    SUM(CASE WHEN outcome = 'Denied' THEN 1 ELSE 0 END)
        AS denied_claims,


    -- Claim rates
    ROUND(
        100.0 * SUM(CASE WHEN outcome = 'Paid' THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0),
        2
    ) AS paid_rate,

    ROUND(
        100.0 * SUM(CASE WHEN outcome = 'Partially Paid' THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0),
        2
    ) AS partial_payment_rate,

    ROUND(
        100.0 * SUM(CASE WHEN outcome = 'Denied' THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0),
        2
    ) AS denial_rate,


    -- Financial KPIs
    SUM(billed_amount) AS total_billed,

    SUM(allowed_amount) AS total_allowed,

    SUM(paid_amount) AS total_paid,

    AVG(paid_amount) AS average_paid_per_claim,

    SUM(
        CASE
            WHEN outcome = 'Denied'
            THEN billed_amount
            ELSE 0
        END
    ) AS denied_billed_amount

FROM gold.fact_claims
where is_valid_diagnosis = True

select * from gold.vw_rcm_kpis_is_valid
