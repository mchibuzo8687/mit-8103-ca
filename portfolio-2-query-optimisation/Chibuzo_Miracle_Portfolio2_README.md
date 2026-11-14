# Portfolio 2 — Query Processing and Optimisation

**Student:** Chibuzo Miracle  
**Student ID:** 301888687  
**Course:** MIT 8103 — Advanced Database Systems  
**Case study:** CareLink Clinic  
**DBMS dialect:** PostgreSQL 14+ (matches Portfolio 1)  
**Status:** Complete

## Purpose

Demonstrate CareLink Clinic operational queries, indexing strategy, execution-plan reasoning, and before/after performance analysis against the Portfolio 1 relational schema.

## Schema dependency

Uses entities from `../portfolio-1-database-design/Chibuzo_Miracle_Schema.sql` only:

Branch, Specialty, Staff, Patient, Appointment, Encounter, Diagnosis, Medication, Prescription, LabTest, LabOrder, Service, Payment.

Portfolio 1 files are **not** modified. Baseline indexes from Schema.sql are reused; additional indexes live in this folder.

## Deliverables

| File | Description |
|------|-------------|
| `Chibuzo_Miracle_Portfolio2_README.md` | This overview |
| `Chibuzo_Miracle_SeedData.sql` | Extended transactional seed (appointments, encounters, labs, Rx, payments) |
| `Chibuzo_Miracle_Queries.sql` | Ten clinic-ops queries (joins, filters, aggregates) |
| `Chibuzo_Miracle_Indexes.sql` | Idempotent `CREATE INDEX` recommendations |
| `Chibuzo_Miracle_QueryOptimisation.md` | Expected results, EXPLAIN commentary, before/after analysis |

## How to run

```bash
psql -U postgres -d carelink -f ../portfolio-1-database-design/Chibuzo_Miracle_Schema.sql
psql -U postgres -d carelink -f Chibuzo_Miracle_SeedData.sql
psql -U postgres -d carelink -f Chibuzo_Miracle_Queries.sql
psql -U postgres -d carelink -f Chibuzo_Miracle_Indexes.sql
# Then re-run EXPLAIN ANALYZE on Q1/Q3 as shown in QueryOptimisation.md
```

## Query scenarios covered

1. Daily branch schedule (Ikeja)  
2. Cross-branch patient clinical history  
3. Revenue by branch and payment method  
4. Outstanding / failed payments  
5. Doctor workload (encounters + prescriptions)  
6. Lab turnaround vs SLA  
7. Active pharmacy dispense queue  
8. No-show / cancellation rates  
9. Abnormal / critical lab alerts  
10. Service catalogue revenue utilisation  

## Evidence note

Where a live PostgreSQL instance was unavailable during authoring, execution plans and sample outputs in `Chibuzo_Miracle_QueryOptimisation.md` are labelled **documented (realistic) evidence** based on PostgreSQL planner behaviour for this schema and index set.
