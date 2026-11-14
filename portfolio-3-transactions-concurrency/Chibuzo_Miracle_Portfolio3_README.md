# Portfolio 3 — Transactions and Concurrency

**Student:** Chibuzo Miracle  
**Student ID:** 301888687  
**Course:** MIT 8103 — Advanced Database Systems  
**Case study:** CareLink Clinic  
**DBMS dialect:** PostgreSQL 14+ (matches Portfolio 1)  
**Status:** Complete

## Purpose

Show how CareLink Clinic protects multi-step clinic operations with transactions (commit / rollback), isolation levels, and concurrency controls — using the real Portfolio 1 schema (Appointment, Encounter, Payment, etc.).

## Schema dependency

Uses `../portfolio-1-database-design/Chibuzo_Miracle_Schema.sql` unchanged. Optional seed from Portfolio 2 improves demo realism:

```bash
psql -U postgres -d carelink -f ../portfolio-1-database-design/Chibuzo_Miracle_Schema.sql
psql -U postgres -d carelink -f ../portfolio-2-query-optimisation/Chibuzo_Miracle_SeedData.sql
psql -U postgres -d carelink -f Chibuzo_Miracle_Transactions.sql
```

## Deliverables

| File | Description |
|------|-------------|
| `Chibuzo_Miracle_Portfolio3_README.md` | This overview |
| `Chibuzo_Miracle_Transactions.sql` | Commit, rollback, and multi-statement clinic transactions |
| `Chibuzo_Miracle_Concurrency.md` | Isolation levels, double-booking, lost update, dirty read, phantom, controls |

## Scenarios covered

1. **Commit** — complete visit: appointment → encounter → diagnosis → payment  
2. **Rollback** — abort incomplete payment when card capture fails  
3. **Constraint-backed double-booking prevention** — `uq_doctor_slot`  
4. **Isolation levels** — READ COMMITTED vs REPEATABLE READ / SERIALIZABLE for payments and appointments  
5. **Concurrency anomalies** — lost update, dirty read, phantom read — with locking / isolation / application patterns  

## Evidence note

Console transcripts in `Chibuzo_Miracle_Concurrency.md` are labelled **documented (realistic) session logs** where a live dual-session PostgreSQL demo was not available during authoring.
