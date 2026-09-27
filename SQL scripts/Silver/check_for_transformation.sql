select * from bronze."claims_raw"
select * from bronze."icd10_raw"
select * from bronze."cpt_hcpcs_raw"

select count(DISTINCT("Claim ID")) from  bronze."claims_raw" 
select count(DISTINCT("Provider ID")) from  bronze."claims_raw"
select count(DISTINCT("Patient ID")) from  bronze."claims_raw"
-- claim id, provider id, patiend id are unique 1000 rows

select
DISTINCT(c."Diagnosis Code"),
icd."description"
from bronze."claims_raw" as c
left join bronze."icd10_raw" as icd 
on c."Diagnosis Code" = icd."diagnosis_code"




select
DISTINCT("Insurance Type"),
count(*)
from  bronze."claims_raw"
group by DISTINCT("Insurance Type")

select
DISTINCT("Claim Status"),
count(*)
from  bronze."claims_raw"
group by DISTINCT("Claim Status")

select
DISTINCT("Follow-up Required"),
count(*)
from  bronze."claims_raw"
group by DISTINCT("Follow-up Required")

select
c."Claim ID",
c."Diagnosis Code",
icd."diagnosis_code"
from bronze."claims_raw" as c
left join bronze."icd10_raw" as icd 
on c."Diagnosis Code" = icd."diagnosis_code"
where icd."diagnosis_code" is NULL

select
c."Claim ID",
c."Diagnosis Code",
icd."diagnosis_code"
from bronze."icd10_raw" as icd 
left join bronze."claims_raw" as c
on c."Diagnosis Code" = icd."diagnosis_code"
where c."Claim ID" is NULL
