# Healthcare Claims & RCM Data Quality Analytics

A SQL-first data-quality and RCM analytics project: synthetic healthcare claims,
reconciled against real CMS diagnosis and procedure reference data, through a
bronze/silver/gold pipeline in PostgreSQL — with every data-quality finding, KPI
definition, and scope decision documented rather than glossed over.

Built as a portfolio project for Data Operations / RCM Analyst roles (Commure and
similar healthcare-tech RCM platforms).

**Core question:** are healthcare revenue-cycle transactions flowing accurately from
claim submission to reimbursement — and where, specifically, does the data itself
break down?

---

## What this project actually does

- Loads a synthetic claims dataset alongside real CMS ICD-10-CM and CPT/HCPCS
  reference data
- Builds a bronze → silver → gold pipeline in PostgreSQL, with silver rebuilt by a
  single idempotent stored procedure (`silver.load_silver()`)
- Measures, rather than assumes, the data's real problems: a 63% ICD-10 diagnosis
  match rate (and explains the other 37%), and a **77.2% mismatch rate between Claim
  Status and Outcome** — the single biggest finding in the project
- Defines a locked, documented source of truth for every RCM KPI, so the SQL never
  produces two contradictory answers to the same question
- Runs denial and root-cause analysis with careful, non-causal language, appropriate
  to data that's close to statistically random
- Says plainly, in every doc, what's real data and what's synthetic, and what was
  deliberately left out and why

---

## Data sources — what's real, what's not

| Source | What it is | Real or synthetic? |
|---|---|---|
| `claims_data.csv` ([AlexTheAnalyst/HealthcareAnalytics](https://github.com/AlexTheAnalyst/HealthcareAnalytics)) | Fact table — 1,000 claims | No documented provenance in the source repo — treated as **realistic synthetic tutorial data** |
| CMS ICD-10-CM Codes File ([cms.gov](https://www.cms.gov/medicare/coding-billing/icd-10-codes)) | Diagnosis reference | **Real** — official CMS government data |
| CMS CPT/HCPCS reference (data.cms.gov) | Procedure codes + descriptions | **Real** codes and descriptions. Pricing data (avg submitted/allowed/payment) was investigated but **not included** — the file obtained didn't have it, and it wasn't worth fabricating. Documented as a future addition. |

**Deliberately not used:** `icd11 codes.csv` (wrong code system — ICD-11 isn't used for
US billing)
---

## Architecture

```
                    RAW SOURCES
        claims_data.csv | CMS ICD-10-CM | CMS CPT/HCPCS
                         │
                         ▼
                  bronze  (raw, untouched — original CSV headers kept as-is)
                         │
                         ▼
         silver  (silver.load_silver() — one stored procedure, fully rebuildable)
   icd10_blocks → icd10 / cpt_hcpcs → claims → icd10_matched / icd10_unmatched
                         │                              → claims_exceptions
                         ▼
         gold  (star schema — one row per claim)
   fact_claims ──┬── dim_diagnosis   (category/chapter enriched)
                 ├── dim_procedure   (code + description, no pricing)
                 ├── dim_payer       (4 rows, tagged Government/Commercial/Self-Pay)
                 └── dim_date
                         │
                         ▼
              sql/qa, sql/views, sql/kpis
```

No `dim_provider` or `dim_patient` — every provider and patient in this dataset has
exactly one claim, so there's no real pattern to model. Building either would be noise
dressed up as a dimension.

---

## Key finding: two fields, two different answers

`claims_data.csv` carries both a `claim_status` field and an `outcome` field, and they
disagree on **77.2% of claims** (772 out of 1,000) — measured directly, not estimated.
A "Paid" claim with a "Denied" outcome, a "Denied" claim with a "Paid" outcome, and
every combination in between, all appear at real volume.

Rather than pick whichever field produces a nicer-looking dashboard, this project
makes one documented decision: **`outcome` is the official source of truth** for every
denial/payment KPI, `claim_status` is retained purely as an operational/QA signal, and
every disagreement between them is logged as its own QA exception. That decision, and
the reasoning behind it, is written down in full in
[`docs/rcm_kpi_definitions.md`](docs/rcm_kpi_definitions.md).

---

## Other real findings

- **ICD-10 diagnosis match rate: ~63%.** The other ~37% aren't bad data — they're
  genuine coding-quality issues: the entire `A16.*` code family has been retired from
  ICD-10-CM (confirmed across all 9 codes in the range), `A09` has no valid decimal
  subdivision at all (so `A09.0`/`A09.9` are invalid, not under-specified), and most of
  the rest need an additional digit to reach a billable code. Documented per-code in
  `silver.icd10_unmatched`.
- **Money is clean.** `paid ≤ allowed ≤ billed` holds across the entire dataset, and
  billed amounts sit in a sane $100–$500 range. The data's problems are entirely in
  status, reason, and diagnosis codes — not the dollar fields.
- **Reason codes sometimes appear on Paid claims**, and AR Status doesn't always agree
  with Claim Status either — both logged as their own QA exceptions.
- **Zero duplicate claim IDs** — tested for anyway, since a QA suite that only reports
  problems it happens to find isn't a complete QA suite.

---

## Tech stack

| Tool | Role |
|---|---|
| **PostgreSQL** (Supabase) | Everything — bronze/silver/gold, all QA, all KPI logic |
| **Python** | One scoped job: `python/build_icd10_reference.py`, parsing the CMS fixed-width ICD-10 file into a clean CSV |


---

## Repository structure

```
rcm-analytics/
├── README.md
├── data/
│   ├── source/            ← raw claims_data.csv, CMS reference downloads
│   └── processed/         ← cleaned CSVs ready for bulk load
├── python/
│   └── build_icd10_reference.py
├── sql/
│   ├── bronze/
│   ├── silver/
│   │   └── load_silver.sql        ← the stored procedure
│   ├── gold/
│   │   └── build_gold.sql
│   ├── qa/
│   │   ├── qa_claim_status_outcome.sql
│   │   └── qa_icd10_matching.sql
│   ├── views/
│   │   ├── vw_claim_quality.sql
│   │   ├── vw_claim_financials.sql
│   │   ├── vw_denial_analysis.sql
│   │   └── vw_rcm_kpis.sql
│   └── kpis/
│       └── rcm_kpi_queries.sql
└── docs/
    ├── rcm_kpi_definitions.md
    └── qa_test_plan.md
```

