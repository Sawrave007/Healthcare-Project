UPDATE silver.icd10_matched
SET
    chapter = 'Certain infectious and parasitic diseases (A00-B99)',

    category = CASE LEFT(diagnosis_code, 3)

        WHEN 'A00' THEN 'Cholera'
        WHEN 'A01' THEN 'Typhoid and paratyphoid fevers'
        WHEN 'A02' THEN 'Other salmonella infections'
        WHEN 'A03' THEN 'Shigellosis'
        WHEN 'A04' THEN 'Other bacterial intestinal infections'
        WHEN 'A05' THEN 'Other bacterial foodborne intoxications'
        WHEN 'A06' THEN 'Amebiasis'
        WHEN 'A07' THEN 'Other protozoal intestinal diseases'
        WHEN 'A08' THEN 'Viral and other specified intestinal infections'
        WHEN 'A09' THEN 'Infectious gastroenteritis and colitis'

        WHEN 'A15' THEN 'Respiratory tuberculosis'
        WHEN 'A16' THEN 'Respiratory tuberculosis'
        WHEN 'A17' THEN 'Tuberculosis of nervous system'
        WHEN 'A18' THEN 'Tuberculosis of other organs'
        WHEN 'A19' THEN 'Miliary tuberculosis'

        ELSE NULL

    END;

select
*
from silver.icd10_matched

SELECT
    category,
    COUNT(*) AS code_count
FROM silver.icd10_matched
GROUP BY category
ORDER BY category;

select
distinct(insurance_type)
from silver.claims

SELECT MIN(date_of_service), MAX(date_of_service) FROM silver.claims;
