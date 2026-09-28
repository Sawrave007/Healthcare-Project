CREATE OR REPLACE VIEW gold.vw_claim_financials AS

SELECT
    DATE_TRUNC('month', date_of_service)::date AS service_month,
    payer_name,
    COUNT(*) AS claim_count,

    SUM(billed_amount) AS total_billed,
    SUM(allowed_amount) AS total_allowed,
    SUM(paid_amount) AS total_paid,

    AVG(billed_amount) AS avg_billed,
    AVG(allowed_amount) AS avg_allowed,
    AVG(paid_amount) AS avg_paid,

    SUM(billed_amount - paid_amount) AS unpaid_amount
FROM gold.fact_claims
where is_valid_diagnosis = True 
GROUP BY
    DATE_TRUNC('month', date_of_service)::date,
    payer_name
ORDER BY
    service_month,
    payer_name;

select * from gold.vw_claim_financials
