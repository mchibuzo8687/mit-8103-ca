# CareLink Clinic — Concurrency and Isolation

**Document type:** Concurrency  
**Student:** Chibuzo Miracle (301888687)  
**DBMS:** PostgreSQL 14+  
**Schema source:** `../portfolio-1-database-design/Chibuzo_Miracle_Schema.sql`

## 1. Why concurrency matters at CareLink

CareLink has concurrent actors:

| Actor | Concurrent risk |
|-------|-----------------|
| Two reception desks | Double-book the same doctor slot; overwrite appointment status |
| Reception + payment terminal | Lost update on payment status / amount |
| Doctor + lab | Phantom rows when counting open lab orders mid-shift |
| Branch managers | Aggregates that include uncommitted payment drafts (dirty read) |

PostgreSQL default isolation is **READ COMMITTED**. Stronger levels and explicit locks are used where clinic correctness requires it.

## 2. Isolation levels (clinic-oriented)

| Level | Dirty read | Non-repeatable read | Phantom | CareLink use |
|-------|------------|---------------------|---------|--------------|
| READ UNCOMMITTED | (treated as RC in PG) | possible | possible | Not used — PG maps to RC |
| READ COMMITTED (default) | prevented | possible | possible | Most OLTP screens |
| REPEATABLE READ | prevented | prevented | reduced* | Payment reconciliation snapshots |
| SERIALIZABLE | prevented | prevented | prevented | Critical slot allocation if app cannot use UNIQUE |

\*In PostgreSQL, REPEATABLE READ also prevents phantoms that would appear under the SQL standard RR definition for many workloads; SERIALIZABLE adds SSI conflict detection.

### Documented session log — non-repeatable read under READ COMMITTED

**Evidence type:** Documented (realistic) dual-session console log.

```text
-- === Session A ===
carelink=# BEGIN ISOLATION LEVEL READ COMMITTED;
BEGIN
carelink=# SELECT payment_id, amount, status FROM payment WHERE reference_no = 'PAY-20261009-002';
 payment_id | amount  | status
------------+---------+---------
          9 | 8000.00 | pending
(1 row)

-- === Session B ===
carelink=# BEGIN;
BEGIN
carelink=# UPDATE payment SET status = 'completed', amount = 8000.00
carelink-# WHERE reference_no = 'PAY-20261009-002';
UPDATE 1
carelink=# COMMIT;
COMMIT

-- === Session A (continues) ===
carelink=# SELECT payment_id, amount, status FROM payment WHERE reference_no = 'PAY-20261009-002';
 payment_id | amount  | status
------------+---------+-----------
          9 | 8000.00 | completed
(1 row)
carelink=# COMMIT;
COMMIT
```

**Clinic meaning:** A finance screen opened under READ COMMITTED can see a payment flip from pending → completed mid-review. Acceptable for live dashboards; unsuitable if the report must be a frozen snapshot.

### Documented session log — snapshot under REPEATABLE READ

```text
-- === Session A ===
carelink=# BEGIN ISOLATION LEVEL REPEATABLE READ;
BEGIN
carelink=# SELECT status FROM payment WHERE reference_no = 'PAY-20261009-002';
  status
---------
 pending

-- === Session B commits status='completed' (same as above) ===

-- === Session A ===
carelink=# SELECT status FROM payment WHERE reference_no = 'PAY-20261009-002';
  status
---------
 pending          -- still the transaction snapshot
carelink=# COMMIT;
COMMIT
```

## 3. Anomaly 1 — Double-booking (write conflict / uniqueness)

### Problem

Two receptionists book Dr Ada Okeke (`staff_id = 1`) at `2026-12-01 09:00` for different patients.

### Schema control (primary defence)

Portfolio 1 defines:

```sql
CONSTRAINT uq_doctor_slot UNIQUE (doctor_id, scheduled_at)
```

### Documented console evidence

```text
-- Session A
BEGIN;
INSERT INTO appointment (patient_id, doctor_id, branch_id, scheduled_at, status, reason)
VALUES (3, 1, 1, '2026-12-01 09:00:00+01', 'booked', 'Reception A');
-- (holds row lock / waits depending on timing)

-- Session B
BEGIN;
INSERT INTO appointment (patient_id, doctor_id, branch_id, scheduled_at, status, reason)
VALUES (4, 1, 1, '2026-12-01 09:00:00+01', 'booked', 'Reception B');

-- When A commits, B fails:
ERROR:  duplicate key value violates unique constraint "uq_doctor_slot"
DETAIL:  Key (doctor_id, scheduled_at)=(1, 2026-12-01 09:00:00+01) already exists.
ROLLBACK;  -- Session B must clear aborted txn
```

### Additional controls

- Application: catch unique_violation and offer next free slot.  
- Optional: `SELECT … FOR UPDATE` on a doctor-day capacity row if CareLink later models slot inventory explicitly.  
- Isolation SERIALIZABLE can serialise competing inserts, but UNIQUE is clearer and cheaper here.

## 4. Anomaly 2 — Lost update on payment

### Problem

Two cashiers adjust the same pending payment:

1. Session A reads `amount = 8000`, plans to apply 10% insurance discount → 7200.  
2. Session B reads `amount = 8000`, plans to add 500 admin fee → 8500.  
3. Both UPDATE — last writer wins; one adjustment is lost.

### Documented illustration

```text
-- Seed row conceptually: payment_id=9, amount=8000, status=pending

-- Session A                          -- Session B
BEGIN;                                BEGIN;
SELECT amount FROM payment            SELECT amount FROM payment
 WHERE payment_id = 9;                 WHERE payment_id = 9;
-- 8000                               -- 8000
UPDATE payment SET amount = 7200   UPDATE payment SET amount = 8500
 WHERE payment_id = 9;                 WHERE payment_id = 9;
COMMIT;                               COMMIT;
-- Final amount = 8500 (A's discount lost) OR 7200 if A committed last
```

### Control mechanisms

1. **Optimistic locking (application pattern):** add `version INT` (or use `updated_at`) and  
   `UPDATE … SET amount = 7200, version = version + 1 WHERE payment_id = 9 AND version = :read_version`  
   → 0 rows updated means conflict; retry.  
2. **Pessimistic locking:**  
   `SELECT amount FROM payment WHERE payment_id = 9 FOR UPDATE;`  
   before computing the new amount (see Demo pattern below).  
3. **Single-statement UPDATE** expressing business rule without read-modify-write in the client:  
   `UPDATE payment SET amount = amount * 0.9 WHERE payment_id = 9 AND status = 'pending';`

### Recommended CareLink pattern (SQL)

```sql
BEGIN;
SELECT payment_id, amount, status
FROM payment
WHERE payment_id = 9
FOR UPDATE;          -- block concurrent modifiers

-- application computes new_amount from locked row
UPDATE payment
SET amount = 7200.00,
    status = 'pending'
WHERE payment_id = 9;

COMMIT;
```

## 5. Anomaly 3 — Dirty read (why PostgreSQL blocks it)

Under the SQL standard, READ UNCOMMITTED allows reading Session B’s uncommitted payment insert. **PostgreSQL does not implement true dirty reads**; READ UNCOMMITTED is treated as READ COMMITTED.

**Clinic implication:** A manager report cannot see a half-entered insurance payment that Session B later ROLLBACKs — good for CareLink financial integrity.

```text
-- Session B
BEGIN;
INSERT INTO payment (..., reference_no, status)
VALUES (..., 'PAY-DIRTY-DEMO', 'pending');
-- not committed

-- Session A (READ COMMITTED)
SELECT * FROM payment WHERE reference_no = 'PAY-DIRTY-DEMO';
-- (0 rows)  -- uncommitted insert not visible

-- Session B
ROLLBACK;
```

## 6. Anomaly 4 — Phantom read on open lab orders

### Problem

Lab supervisor counts open orders, then re-counts after another session inserts a new `lab_order` — the count “phantoms” upward mid-decision.

```text
-- Session A: BEGIN ISOLATION LEVEL READ COMMITTED;
SELECT COUNT(*) FROM lab_order WHERE status IN ('ordered', 'in_progress');
-- count = 2

-- Session B: INSERT new lab_order status='ordered'; COMMIT;

-- Session A:
SELECT COUNT(*) FROM lab_order WHERE status IN ('ordered', 'in_progress');
-- count = 3   -- phantom
COMMIT;
```

### Controls

- Use **REPEATABLE READ** or **SERIALIZABLE** for the counting transaction if staffing decisions must see a stable set.  
- Or materialise a worklist into a temp table / queue snapshot at transaction start.  
- Partial index `idx_lab_order_status_ordered` (Portfolio 2) speeds the predicate but does not by itself prevent phantoms.

## 7. End-to-end CareLink control map

| Scenario | Risk | Primary control | Supporting control |
|----------|------|-----------------|--------------------|
| Same doctor + same timestamp | Double booking | `uq_doctor_slot` UNIQUE | App retry / next slot |
| Complete visit + bill | Partial write | Multi-statement txn + COMMIT | ROLLBACK on gateway decline |
| Concurrent payment edits | Lost update | `SELECT … FOR UPDATE` or version column | Idempotent status transitions |
| Manager reading drafts | Dirty read | PG MVCC (RC+) | Never rely on RU |
| Lab open-order count | Phantom | REPEATABLE READ / SERIALIZABLE | Snapshot worklist |
| Retry after timeout | Duplicate payment | Idempotent `UPDATE … WHERE status='pending'` + unique `reference_no` | |

## 8. Link to executable demos

Runnable scripts live in `Chibuzo_Miracle_Transactions.sql`:

- Demo 1 — COMMIT multi-step visit  
- Demo 2 — ROLLBACK failed card payment  
- Demo 3 — ROLLBACK after double-book constraint error  
- Demo 4 — SAVEPOINT keeps appointment, undoes payment  
- Demo 5 — Idempotent payment completion  
- Demo 6 — Isolation level session templates  

## 9. Assumptions

- Appointment / payment IDs referenced in demos assume Portfolio 1 clean load + Portfolio 2 seed unless otherwise noted.  
- Demo 1 mutates appointment 8; re-run on a fresh database if repeating.  
- No schema objects were invented beyond Portfolio 1; concurrency discussion uses existing constraints (`uq_doctor_slot`, `uq_payment_reference`, status CHECKs).
