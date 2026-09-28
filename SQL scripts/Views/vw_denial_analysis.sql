CREATE OR REPLACE VIEW gold.vw_denial_analysis AS

SELECT
    DATE_TRUNC('month', date_of_service)::date AS service_month,
    payer_name,
    reason_code,

    COUNT(*) AS denied_claims,
    SUM(billed_amount) AS denied_billed_amount

FROM gold.fact_claims

WHERE outcome = 'Denied'

GROUP BY
    DATE_TRUNC('month', date_of_service)::date,
    payer_name,
    reason_code

ORDER BY
    service_month,
    payer_name,
    denied_claims DESC;

select * from gold.vw_denial_analysis
