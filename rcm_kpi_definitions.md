# RCM KPI Definitions

## 1. Purpose

This document defines the RCM KPIs in the **RCM Analytics** project.

The purpose is to make every KPI:

* clearly defined
* reproducible
* consistent across SQL and Power BI
* tied to a documented source field
* explicit about limitations


# 2. KPI Source of Truth

## Status vs Outcome Decision

The claims dataset contains two operational fields:

* `claim_status`
* `outcome`

These fields are frequently inconsistent.

The current validation of `gold.fact_claims` showed these mismatched combinations:

| Claim Status                | Outcome        |  Claims |
| --------------------------- | -------------- | ------: |
| Under Review                | Paid           |     122 |
| Under Review                | Denied         |     120 |
| Paid                        | Partially Paid |     119 |
| Denied                      | Paid           |     119 |
| Paid                        | Denied         |      99 |
| Denied                      | Partially Paid |      97 |
| Under Review                | Partially Paid |      96 |
| **Total mismatched claims** |                | **772** |

With 1,000 claims in the dataset, this represents a **77.2% Status/Outcome mismatch rate**.

Because the two fields disagree so frequently, both fields cannot independently define denial or payment KPIs without producing contradictory results.

## Project Decision

**`outcome` is the single source of truth for denial and payment KPIs.**

`claim_status` is retained as an operational field and is used for data-quality investigation.

Therefore:

```text
outcome
   ↓
Official KPI source of truth

claim_status ↔ outcome
   ↓
QA investigation
```

### Official outcome categories

The project recognizes the following outcome categories:

* `Paid`
* `Partially Paid`
* `Denied`

Any unexpected or null outcome should be classified as a **data-quality issue** and should not silently be included in official outcome-based KPI calculations.

---

# 3. Core Dataset Grain

The primary analytical grain is:

> **One row = one healthcare claim.**

Unless otherwise specified, all claim-level KPIs use:

```sql
COUNT(*) 
```

or:

```sql
COUNT(DISTINCT claim_id)
```

depending on whether `claim_id` uniqueness has been formally validated.

The preferred approach is to use `COUNT(DISTINCT claim_id)` when a stable unique claim identifier exists.

Before finalizing production KPIs, claim uniqueness must be validated.

---

# 4. Core RCM KPIs

## 4.1 Total Claims

### Definition

The total number of valid claims included in the analytical dataset.

### Formula

```text
Total Claims = Count of claims
```

### SQL concept

```sql
COUNT(DISTINCT claim_id)
```

### Source

* Claim identifier
* `gold.fact_claims`

### Purpose

Provides the denominator and overall volume context for other claim-level KPIs.

### Notes

Claims with invalid or missing identifiers should be investigated separately as data-quality issues.

---

# 5. Outcome KPIs

## 5.1 Paid Claims

### Definition

Number of claims where the official `outcome` is `Paid`.

### Formula

```text
Paid Claims =
Count of claims where outcome = 'Paid'
```

### SQL concept

```sql
COUNT(DISTINCT CASE
    WHEN outcome = 'Paid' THEN claim_id
END)
```

### Source of truth

```text
outcome
```

### Purpose

Measures the volume of claims that reached a paid outcome.

---

## 5.2 Partially Paid Claims

### Definition

Number of claims where the official `outcome` is `Partially Paid`.

### Formula

```text
Partially Paid Claims =
Count of claims where outcome = 'Partially Paid'
```

### SQL concept

```sql
COUNT(DISTINCT CASE
    WHEN outcome = 'Partially Paid' THEN claim_id
END)
```

### Purpose

Identifies claims where payment was received but was not classified as fully paid.

---

## 5.3 Denied Claims

### Definition

Number of claims where the official `outcome` is `Denied`.

### Formula

```text
Denied Claims =
Count of claims where outcome = 'Denied'
```

### SQL concept

```sql
COUNT(DISTINCT CASE
    WHEN outcome = 'Denied' THEN claim_id
END)
```

### Source of truth

```text
outcome
```

### Purpose

Measures denial volume and serves as the foundation for denial-rate and denial-reason analysis.

---

# 6. Outcome Rate KPIs

## 6.1 Denial Rate

### Definition

The percentage of valid claims whose official outcome is `Denied`.

### Formula

```text
Denial Rate =
Denied Claims / Total Claims × 100
```

### SQL concept

```sql
100.0 *
COUNT(DISTINCT CASE
    WHEN outcome = 'Denied' THEN claim_id
END)
/
NULLIF(COUNT(DISTINCT claim_id), 0)
```

### Source of truth

```text
outcome
```

### Interpretation

A higher denial rate indicates that a larger proportion of submitted claims ended in a denied outcome.

### Important limitation

The dataset is synthetic and should not be interpreted as representing the actual denial rate of a real healthcare organization.

---

## 6.2 Paid Rate

### Definition

The percentage of valid claims whose official outcome is `Paid`.

### Formula

```text
Paid Rate =
Paid Claims / Total Claims × 100
```

### SQL concept

```sql
100.0 *
COUNT(DISTINCT CASE
    WHEN outcome = 'Paid' THEN claim_id
END)
/
NULLIF(COUNT(DISTINCT claim_id), 0)
```

---

## 6.3 Partial Payment Rate

### Definition

The percentage of valid claims whose official outcome is `Partially Paid`.

### Formula

```text
Partial Payment Rate =
Partially Paid Claims / Total Claims × 100
```

### SQL concept

```sql
100.0 *
COUNT(DISTINCT CASE
    WHEN outcome = 'Partially Paid' THEN claim_id
END)
/
NULLIF(COUNT(DISTINCT claim_id), 0)
```

---

# 7. Payment Resolution Rate

## 7.1 Resolved Claim Rate

### Definition

The percentage of claims that have reached either a `Paid`, `Partially Paid`, or `Denied` outcome.

Because these are the defined terminal outcome categories in the dataset:

```text
Resolved Claims =
Paid + Partially Paid + Denied
```

### Formula

```text
Resolved Claim Rate =
Resolved Claims / Total Claims × 100
```

### SQL concept

```sql
100.0 *
COUNT(DISTINCT CASE
    WHEN outcome IN ('Paid', 'Partially Paid', 'Denied')
    THEN claim_id
END)
/
NULLIF(COUNT(DISTINCT claim_id), 0)
```

### Important note

This KPI is outcome-based.

It must **not** use `claim_status = 'Paid'` or `claim_status = 'Denied'` as the resolution definition.

---

# 8. Denial Analysis KPIs

## 8.1 Denial Reason Volume

### Definition

The number of denied claims grouped by denial reason.

### Filter

```text
outcome = 'Denied'
```

### Grouping

```text
denial_reason
```

### SQL concept

```sql
SELECT
    reason_code,
    COUNT(DISTINCT claim_id) AS denied_claims
FROM gold.fact_claims
WHERE outcome = 'Denied'
GROUP BY reason_code
ORDER BY denied_claims DESC;
```

### Purpose

Identifies the most frequent reasons associated with denied claims.

### Important limitation

Frequency alone does not establish the financial impact of a denial reason.

---

## 8.2 Denial Reason Rate

### Definition

The percentage of denied claims associated with each denial reason.

### Formula

```text
Denial Reason Rate =
Claims for Reason / Total Denied Claims × 100
```

### Example

If 100 claims are denied and 25 have the reason:

```text
Incorrect Billing Information
```

then:

```text
Denial Reason Rate = 25 / 100 × 100 = 25%
```

### Purpose

Shows the composition of the denial population.

---

# 9. RCM Outcome by Operational Status

## 9.1 Status/Outcome Mismatch Rate

### Definition

The percentage of claims where `claim_status` and `outcome` do not represent the same result.

### Formula

```text
Status/Outcome Mismatch Rate =
Mismatched Claims / Total Claims × 100
```

### SQL concept

```sql
100.0 *
COUNT(DISTINCT CASE
    WHEN claim_status <> outcome
    THEN claim_id
END)
/
NULLIF(COUNT(DISTINCT claim_id), 0)
```

### Source fields

```text
claim_status
outcome
```

### Purpose

Measures operational data inconsistency.

### Important distinction

This is a **data-quality KPI**, not an RCM financial-performance KPI.

It should therefore be presented separately from denial rate, payment rate, and other business KPIs.

---

# 10. Claim Status KPIs

Because `claim_status` is not the official source of truth for payment or denial, status-based metrics are considered **operational monitoring metrics**.

## 10.1 Claims by Status

### Definition

Number of claims grouped by `claim_status`.

### SQL concept

```sql
SELECT
    claim_status,
    COUNT(DISTINCT claim_id) AS claim_count
FROM gold.fact_claims
GROUP BY claim_status
ORDER BY claim_count DESC;
```

### Purpose

Shows the operational distribution of claims.

### Warning

Do not label:

```text
claim_status = 'Denied'
```

as the official denied-claim population.

Official denial KPIs must use:

```text
outcome = 'Denied'
```

---

# 11. AR / Follow-Up KPIs

The project may contain fields related to follow-up and accounts receivable, such as:

* `ar_status`
* `follow_up`
* `outcome`
* denial reason fields

These fields must be treated carefully because they represent different operational concepts.

## 11.1 AR Status Distribution

### Definition

Number of claims grouped by `ar_status`.

### Purpose

Shows the distribution of claims across the available AR workflow statuses.

### SQL concept

```sql
SELECT
    ar_status,
    COUNT(DISTINCT claim_id) AS claim_count
FROM gold.fact_claims
GROUP BY ar_status
ORDER BY claim_count DESC;
```

### Important limitation

`ar_status` must not be assumed to represent payment outcome.

For example:

```text
AR Status = Closed
Outcome = Paid
```

does not mean the AR status itself determined that the claim was paid.

The payment classification comes from:

```text
outcome
```

---

# 12. AR Outcome Consistency

## 12.1 Closed AR Claims With Non-Paid Outcomes

### Definition

Claims where:

```text
ar_status = 'Closed'
```

but:

```text
outcome <> 'Paid'
```

### Purpose

Identifies potentially interesting operational cases where the AR workflow is marked closed while the claim outcome is not fully paid.

### SQL concept

```sql
SELECT
    COUNT(DISTINCT claim_id) AS closed_non_paid_claims
FROM gold.fact_claims
WHERE ar_status = 'Closed'
  AND outcome <> 'Paid';
```

### Interpretation

This metric should be treated as a **QA / workflow investigation metric**, not automatically as an error.

A closed AR case may have a legitimate business explanation.

---

# 13. Financial KPIs

Financial KPIs should only be implemented if the dataset contains reliable financial fields.

Potential fields include:

* billed amount
* allowed amount
* paid amount
* adjustment amount
* patient responsibility
* outstanding amount

These fields must be validated before being used in official financial KPIs.

---

## 13.1 Total Billed Amount

### Definition

Total billed amount associated with valid claims.

### Formula

```text
Total Billed =
SUM(billed_amount)
```

### SQL concept

```sql
SUM(billed_amount)
```

### Validation requirement

Before using this KPI, confirm:

* numeric data type
* currency consistency
* no duplicated claims
* treatment of null values
* treatment of negative values
* whether the amount is claim-level or line-level

---

## 13.2 Total Paid Amount

### Definition

Total amount recorded as paid.

### Formula

```text
Total Paid =
SUM(paid_amount)
```

### Important distinction

`outcome = 'Paid'` and `paid_amount` are different concepts.

For example:

```text
outcome = Paid
```

describes the claim's categorical outcome.

```text
paid_amount = 500
```

describes the monetary amount.

Neither should be substituted for the other.

---

## 13.3 Outstanding Amount

### Definition

The amount remaining unpaid, if a reliable outstanding balance field exists.

### Formula

If the dataset defines outstanding balance directly:

```text
Outstanding Amount =
SUM(outstanding_amount)
```

If it must be derived:

```text
Outstanding Amount =
Billed Amount - Paid Amount - Valid Adjustments
```

### Important limitation

Do not derive this KPI until the financial fields and adjustment logic have been validated.

---

# 14. Denial Financial Impact

## 14.1 Denied Claim Amount

If a valid claim amount exists, the project may calculate the financial exposure associated with denied claims.

### Definition

Total claim amount associated with claims whose outcome is `Denied`.

### Formula

```text
Denied Claim Amount =
SUM(claim_amount)
WHERE outcome = 'Denied'
```

### SQL concept

```sql
SUM(
    CASE
        WHEN outcome = 'Denied'
        THEN claim_amount
        ELSE 0
    END
)
```

### Important limitation

This is **not automatically equivalent to lost revenue**.

A denied claim may later be:

* corrected
* resubmitted
* appealed
* partially paid
* fully paid

Therefore the metric should be described as **denied claim amount / financial exposure**, unless the dataset contains evidence that the amount was permanently lost.

---

# 15. Claim-Level QA KPIs

These metrics are designed to demonstrate data-quality and analytical reasoning.

## 15.1 Missing Outcome Rate

### Definition

Percentage of claims where the official `outcome` field is null or blank.

### Formula

```text
Missing Outcome Rate =
Claims with Missing Outcome / Total Claims × 100
```

### Purpose

Identifies claims that cannot be reliably classified using the project's official outcome logic.

---

## 15.2 Missing Denial Reason Among Denied Claims

### Definition

Percentage of denied claims that do not contain a denial reason.

### Formula

```text
Missing Denial Reason Rate =
Denied Claims Without Reason / Total Denied Claims × 100
```

### SQL concept

```sql
100.0 *
COUNT(DISTINCT CASE
    WHEN outcome = 'Denied'
     AND (
         denial_reason IS NULL
         OR TRIM(denial_reason) = ''
     )
    THEN claim_id
END)
/
NULLIF(
    COUNT(DISTINCT CASE
        WHEN outcome = 'Denied'
        THEN claim_id
    END),
    0
)
```

### Purpose

Measures whether denied claims contain sufficient information for root-cause analysis.

---

## 15.3 Duplicate Claim Rate

### Definition

Percentage of claim records associated with duplicate claim identifiers.

### Purpose

Detects potential duplication before calculating claim-level KPIs.

### Important requirement

The exact implementation depends on the uniqueness rule for `claim_id`.

Do not automatically delete duplicates.

First determine whether multiple rows represent:

* duplicate records
* claim lines
* adjustments
* resubmissions
* legitimate multiple records

---

# 16. KPI Dimension Analysis

All core KPIs should be capable of being analyzed across relevant dimensions where those dimensions exist and are validated.

Potential dimensions include:

* provider
* payer
* procedure code
* diagnosis code
* claim type
* claim status
* AR status
* denial reason
* date
* geography

Example:

```text
Denial Rate by Provider
Denial Rate by Procedure Code
Denial Rate by Payer
Denial Rate by Denial Reason
```

The underlying KPI definition does not change when the dimension changes.

For example:

```text
Denial Rate by Provider
=
Denied Claims for Provider
/
Total Claims for Provider
```

where denial is still determined by:

```text
outcome = 'Denied'
```

---

# 17. Time-Based KPIs

If a valid claim date is available, the project may analyze KPIs by:

* day
* week
* month
* quarter
* year

Example:

```text
Monthly Denial Rate
=
Monthly Denied Claims
/
Monthly Total Claims
× 100
```

### Important requirement

The date used must be explicitly documented.

Possible dates could include:

* claim submission date
* service date
* processing date
* payment date
* denial date

These dates represent different business events and must not be treated as interchangeable.

---

# 18. Power BI KPI Rules

Power BI measures must follow the definitions in this document.

The dashboard must not create alternative versions of official KPIs using different filters.

## Official source of truth

```text
Denial → outcome = 'Denied'

Paid → outcome = 'Paid'

Partially Paid → outcome = 'Partially Paid'
```

## Operational QA

```text
claim_status ↔ outcome
```

## AR workflow

```text
ar_status
```

## Denial analysis

```text
outcome = 'Denied'
    ↓
denial_reason
```

This separation prevents the dashboard from mixing:

* claim outcome
* operational status
* AR workflow status
* data-quality findings

---

# 19. KPI Naming Standards

Use consistent names across SQL, documentation, and Power BI.

| Business Definition              | Standard KPI Name              |
| -------------------------------- | ------------------------------ |
| Total claims                     | `Total Claims`                 |
| Paid claims                      | `Paid Claims`                  |
| Partially paid claims            | `Partially Paid Claims`        |
| Denied claims                    | `Denied Claims`                |
| Paid percentage                  | `Paid Rate`                    |
| Partially paid percentage        | `Partial Payment Rate`         |
| Denied percentage                | `Denial Rate`                  |
| Resolved percentage              | `Resolved Claim Rate`          |
| Status/outcome inconsistency     | `Status/Outcome Mismatch Rate` |
| Missing outcome percentage       | `Missing Outcome Rate`         |
| Missing denial reason percentage | `Missing Denial Reason Rate`   |
| AR status distribution           | `AR Status Distribution`       |

Avoid creating multiple names for the same KPI.

For example, do not use:

```text
Denial %
Denied %
Denial Ratio
Claim Denial %
```

for four different Power BI measures if they all represent the same definition.

Use:

```text
Denial Rate
```

consistently.

---

# 20. KPI Calculation Principles

The following principles apply to every KPI.

## Principle 1 — Define Before Calculating

Every KPI must have:

1. Business definition
2. Source field
3. Formula
4. Filter logic
5. Denominator
6. Known limitations

---

## Principle 2 — Never Hide Data Quality Problems

If source fields conflict, do not silently choose whichever produces the preferred result.

Document the conflict.

For this project:

```text
claim_status
      ↕
  conflict
      ↕
outcome
```

The project explicitly selected `outcome` as the official source of truth.

---

## Principle 3 — Denominator Must Be Explicit

A percentage without a clearly defined denominator is not a reliable KPI.

For example:

```text
Denial Rate
```

must mean:

```text
Denied Claims / Total Claims
```

not:

```text
Denied Claims / Claims with Denial Reasons
```

unless explicitly stated.

---

## Principle 4 — Avoid Division by Zero

SQL calculations must protect against zero denominators.

Preferred pattern:

```sql
NULLIF(denominator, 0)
```

---

## Principle 5 — Nulls Must Be Intentional

Null values must not be silently converted into meaningful business categories.

For example:

```text
NULL outcome
```

does not mean:

```text
Under Review
```

unless the source system explicitly defines it that way.

---

## Principle 6 — Synthetic Data Limitations

The project uses synthetic claims data.

Therefore:

* KPI values demonstrate analytical methodology
* observed rates should not be presented as real-world healthcare benchmarks
* financial results should not be presented as actual Commure financial performance
* operational findings should be described as findings within the dataset

---

# 21. Recommended Executive KPI Layer

The Power BI executive page should focus on a small number of high-value KPIs rather than displaying every available metric.

Recommended primary KPIs:

```text
Total Claims
Denied Claims
Denial Rate
Paid Claims
Paid Rate
Partially Paid Claims
Status/Outcome Mismatch Rate
```

Supporting analytical sections can then investigate:

```text
Denial Reasons
Provider
Procedure Code
Payer
AR Status
Time
```

The QA metrics should be visually separated from business-performance KPIs.

---

# 22. KPI Dependency Map

The project's analytical logic can be summarized as:

```text
                         gold.fact_claims
                                |
             +------------------+------------------+
             |                  |                  |
             v                  v                  v
          outcome        claim_status          ar_status
             |                  |                  |
      +------+------+            |           Workflow Analysis
      |      |      |            |
      v      v      v            v
    Paid  Partial Denied    QA / Mismatch
      |      |      |
      |      |      +----------------+
      |      |                       |
      v      v                       v
   Rates   Rates              denial_reason
                                      |
                                      v
                              Root Cause Analysis
                                      |
                                      v
                              Business Impact
```

This architecture intentionally separates:

```text
Business Outcome
       ↓
RCM KPI

Operational Status
       ↓
Data Quality / Workflow QA

Denial Reason
       ↓
Root Cause Analysis
```

---

# 23. Official KPI Contract

The following rules are considered locked for this project unless new validated source information requires a documented revision.

### Rule 1

**`outcome` is the official source of truth for claim payment and denial outcomes.**

### Rule 2

**`claim_status` is an operational field and a QA investigation field.**

### Rule 3

**Denial KPIs use `outcome = 'Denied'`.**

### Rule 4

**Paid KPIs use `outcome = 'Paid'`.**

### Rule 5

**Partial-payment KPIs use `outcome = 'Partially Paid'`.**

### Rule 6

**Denial reasons are analyzed only within the denied population unless otherwise specified.**

### Rule 7

**Status/outcome mismatches are reported as data-quality findings, not silently corrected.**

### Rule 8

**Financial KPIs require validation of the underlying monetary fields before becoming official KPIs.**

### Rule 9

**Every percentage KPI must have an explicit denominator.**

### Rule 10

**Power BI measures must implement these definitions rather than independently redefining business logic.**

---

# 24. Version Control

**Document:** `rcm_kpi_definitions.md`

**Project:**   Healthcare & RCM Analytics

**Version:** 1.0

**Primary outcome source:** `outcome`

**QA source:** `claim_status`

**Primary analytical table:** `gold.fact_claims`
