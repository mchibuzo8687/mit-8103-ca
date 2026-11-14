# CareLink Clinic — Query Optimisation Analysis

**Document type:** QueryOptimisation  
**Student:** Chibuzo Miracle (301888687)  
**DBMS:** PostgreSQL 14+  
**Schema source:** `../portfolio-1-database-design/Chibuzo_Miracle_Schema.sql`

## 1. Workload overview

| Query | Business purpose | Dominant access pattern |
|-------|------------------|-------------------------|
| Q1 | Daily branch schedule | Equality on branch + range on `scheduled_at` + status filter |
| Q2 | Patient history | Equality on `patient_number` + join fan-out to encounter/diagnosis |
| Q3 | Monthly revenue by branch/method | Date range on `paid_at` + status + join to appointment/branch |
| Q4 | Finance chase list | Filter `payment.status IN ('pending','failed')` |
| Q5 | Doctor workload | Group by doctor with LEFT JOIN encounter/prescription |
| Q6 | Lab SLA | Completed lab orders + elapsed-time expression |
| Q7 | Pharmacy queue | Partial filter `prescription.status = 'active'` |
| Q8 | Lost-slot quality metric | Aggregate with `FILTER` by status |
| Q9 | Clinical alerts | Partial filter on `result_flag` |
| Q10 | Service utilisation | Group by service with conditional aggregates |

## 2. Expected / sample results (from seed data)

**Evidence type:** Documented expected output derived from `Chibuzo_Miracle_SeedData.sql` (not a live `psql` capture).

### Q1 — Ikeja schedule on 2026-11-10

| appointment_id | scheduled_at | status | patient | doctor |
|----------------|--------------|--------|---------|--------|
| 8 | 2026-11-10 10:00 | booked | PAT-1002 Blessing Ojo | DOC-001 Ada Okeke |

(Only appointment 8 is at CL-IKE on that day with a live status; appointment 7 is at CL-VI with DOC-004.)

### Q3 — October 2026 completed revenue (illustrative)

| branch_code | method | payment_count | total_amount |
|-------------|--------|---------------|--------------|
| CL-IKE | card | 2 | 23000.00 |
| CL-IKE | cash | 2 | 25000.00 |
| CL-IKE | transfer | 1 | 15000.00 |
| CL-VI | card | 1 | 15000.00 |
| CL-VI | insurance | 2 | 23000.00 |

Exact row counts depend on seed join paths; totals should sum completed October payments linked via appointments.

### Q4 — Outstanding payments

Expect at least:

- `PAY-20261009-002` pending (lab panel for PAT-1006)  
- `PAY-20261110-001` pending (consultation for PAT-1001)  
- `PAY-20261110-002` failed (follow-up for PAT-1002)

### Q7 — Active prescriptions

Expect Atorvastatin (encounter 2) and Metformin (encounter 6) with status `active`.

### Q9 — Abnormal labs

Expect FBC (mild anaemia) and Lipid Profile (elevated LDL) for patient PAT-1004 / encounter 4.

## 3. Indexing strategy

### Already in Portfolio 1 (baseline)

- `idx_appointment_branch_time (branch_id, scheduled_at)`  
- `idx_appointment_doctor_time (doctor_id, scheduled_at)`  
- `idx_appointment_patient`, `idx_appointment_status`  
- `idx_payment_patient`, `idx_payment_paid_at`  
- Encounter / diagnosis / prescription / lab_order FK support indexes  

### Added in Portfolio 2 (`Chibuzo_Miracle_Indexes.sql`)

| Index | Rationale |
|-------|-----------|
| `idx_appointment_live_schedule` (partial) | Schedule board ignores cancelled/no_show → smaller index |
| `idx_payment_status_paid_at` | Q3/Q4 predicates on status + date |
| `idx_payment_appointment`, `idx_payment_service` | Join support for revenue reports |
| `idx_encounter_doctor` | Q5 GROUP BY doctor |
| `idx_lab_order_status_ordered` | Lab queue / SLA filters |
| `idx_prescription_active_prescribed` (partial) | Pharmacy queue |
| `idx_lab_order_abnormal` (partial) | Clinical alert list |
| `idx_patient_number`, `idx_branch_code` | Natural-key lookups used in WHERE clauses |

**Design principles:** composite indexes match left-prefix filter order; partial indexes shrink hot paths; avoid redundant indexes that duplicate UNIQUE/PK already present (`uq_doctor_slot`, primary keys).

## 4. Execution plan discussion

**Evidence type:** Documented (realistic) `EXPLAIN (ANALYZE, BUFFERS)` commentary — PostgreSQL not running in the authoring environment. Plans reflect expected behaviour after `ANALYZE` on seeded tables.

### 4.1 Q1 — Daily schedule (before vs after extra indexes)

**Before** (baseline only — `idx_appointment_branch_time` present):

```text
Nested Loop
  -> Nested Loop
       -> Nested Loop
            -> Index Scan using idx_appointment_branch_time on appointment a
                 Index Cond: (branch_id = 1 AND scheduled_at >= ... AND scheduled_at < ...)
                 Filter: (status = ANY (...))
                 Rows Removed by Filter: (cancelled/no_show rows in range)
            -> Index Scan using patient_pkey on patient p
       -> Index Scan using staff_pkey on staff s
  -> Seq Scan on branch b
       Filter: (branch_code = 'CL-IKE')
Planning Time: ~0.4 ms
Execution Time: ~0.8 ms (tiny seed) / grows with appointments per day
```

**After** (`idx_appointment_live_schedule` + `idx_branch_code`):

```text
Nested Loop
  -> Index Scan using idx_branch_code on branch b
       Index Cond: (branch_code = 'CL-IKE')
  -> Index Scan using idx_appointment_live_schedule on appointment a
       Index Cond: (branch_id = b.branch_id AND scheduled_at >= ... AND scheduled_at < ...)
       -- cancelled/no_show never enter the index (partial)
  -> Index Scan using patient_pkey / staff_pkey ...
Heap Fetches reduced; Filter rows removed → 0 on status
Execution Time: lower I/O on large appointment histories
```

**Interpretation:** On small seed data both plans are sub-millisecond. Benefit appears when each branch holds months of appointments including many cancelled/no_show rows — the partial index avoids touching those heap tuples for the schedule board.

### 4.2 Q3 — Revenue aggregation (before vs after)

**Before** (only `idx_payment_paid_at`):

```text
HashAggregate
  -> Hash Join
       -> Hash Join
            -> Seq Scan / Bitmap Heap Scan on payment pay
                 Filter: (status = 'completed' AND paid_at >= ... AND paid_at < ...)
                 -- may recheck many non-completed rows if only paid_at index used
            -> Hash (appointment)
       -> Hash (branch)
```

**After** (`idx_payment_status_paid_at` + `idx_payment_appointment`):

```text
HashAggregate
  -> Nested Loop / Hash Join
       -> Bitmap Index Scan on idx_payment_status_paid_at
            Index Cond: (status = 'completed' AND paid_at >= ... AND paid_at < ...)
       -> Index Scan using idx_payment_appointment → appointment → branch
```

**Interpretation:** Leading with `(status, paid_at)` matches the filter selectivity of completed payments in a month, reducing rows fed into the hash aggregate.

### 4.3 Q2 — Patient history

With `idx_patient_number` + `idx_appointment_patient`, the planner typically:

1. Index lookup patient by number (1 row)  
2. Index Nested Loop into appointments  
3. Nested Loop / Merge into encounter (unique on `appointment_id`)  
4. Nested Loop into diagnosis  

This is the preferred plan for OLTP “open chart” queries; a sequential scan of appointment would only win on empty/tiny databases.

## 5. Before / after performance analysis (summary)

| Metric | Before extra Portfolio 2 indexes | After Portfolio 2 indexes |
|--------|----------------------------------|---------------------------|
| Q1 schedule on large history | Index range scan + status filter removals | Partial index → fewer heap fetches |
| Q3 month finance | Date index + post-filter status | Composite `(status, paid_at)` seeks completed window directly |
| Q7 pharmacy | Full/index scan of all prescriptions | Partial active-only index |
| Q9 alerts | Scan lab_order + filter flags | Partial abnormal/critical index |
| Write overhead | Lower | Slightly higher on INSERT/UPDATE of indexed tables (acceptable for CareLink OLTP) |

**Trade-off:** Extra indexes cost storage and slow bulk loads slightly. CareLink is read-heavy for reception/doctor screens during clinic hours, so selective secondary/partial indexes are justified.

## 6. Recommendations for production

1. Keep Portfolio 1 UNIQUE constraint `uq_doctor_slot (doctor_id, scheduled_at)` — it is a correctness control, not only an optimisation.  
2. Run `ANALYZE` after bulk seed or ETL.  
3. Monitor `pg_stat_user_indexes` and drop unused indexes.  
4. Prefer covering/partial indexes for hot status filters (`booked`, `active`, `abnormal`).  
5. For very large payment history, consider partitioning `payment` by month (discussion only — out of scope for CA scripts).

## 7. Assumptions

- Seed IDs follow SERIAL order after a clean Portfolio 1 load then Portfolio 2 seed.  
- Time zone offsets in seed use `+01` for Lagos-local demonstration timestamps.  
- No conflicting schema invented; all objects exist in Portfolio 1.
