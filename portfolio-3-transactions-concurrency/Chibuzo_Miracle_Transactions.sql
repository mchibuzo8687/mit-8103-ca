-- =============================================================================
-- CareLink Clinic — Transactions Demonstrations (Portfolio 3)
-- Student: Chibuzo Miracle (301888687)
-- Dialect: PostgreSQL 14+
-- Prerequisite: Portfolio 1 schema; Portfolio 2 seed recommended
--
-- Run sections interactively. Each demo is self-contained where possible.
-- Comments mark expected outcomes.
-- =============================================================================

-- Show current defaults
SHOW default_transaction_isolation;  -- typically read committed
SHOW transaction_isolation;

-- =============================================================================
-- DEMO 1: COMMIT — Atomic “complete booked visit”
-- Reception checks patient in, doctor records encounter + diagnosis, payment taken.
-- All succeed → COMMIT. Partial failure must not leave orphan clinical rows.
-- =============================================================================

BEGIN;

-- Assume appointment_id = 8 is PAT-1002 / DOC-001 / booked (from Portfolio 2 seed)
UPDATE appointment
SET status = 'checked_in',
    updated_at = NOW()
WHERE appointment_id = 8
  AND status = 'booked';

-- Guard: ensure exactly one row moved to checked_in
-- (application should abort if GET DIAGNOSTICS row_count = 0)

UPDATE appointment
SET status = 'completed',
    updated_at = NOW()
WHERE appointment_id = 8
  AND status = 'checked_in';

INSERT INTO encounter (appointment_id, patient_id, doctor_id, encounter_at, chief_complaint, clinical_notes)
VALUES (
    8,
    2,
    1,
    NOW(),
    'Blood pressure review',
    'BP 128/82; continue current lifestyle measures.'
);

INSERT INTO diagnosis (encounter_id, icd_code, description, severity)
VALUES (
    currval(pg_get_serial_sequence('encounter', 'encounter_id')),
    'I10',
    'Essential (primary) hypertension',
    'mild'
);

INSERT INTO payment (
    patient_id, appointment_id, service_id, amount, method, status, paid_at, reference_no
) VALUES (
    2,
    8,
    3,                 -- SVC-FOL Follow-up Visit
    10000.00,
    'card',
    'completed',
    NOW(),
    'PAY-TX-DEMO1-COMMIT'
);

COMMIT;

-- Verification
SELECT a.appointment_id, a.status, e.encounter_id, d.icd_code, p.reference_no, p.amount
FROM appointment a
LEFT JOIN encounter e ON e.appointment_id = a.appointment_id
LEFT JOIN diagnosis d ON d.encounter_id = e.encounter_id
LEFT JOIN payment p ON p.appointment_id = a.appointment_id AND p.reference_no = 'PAY-TX-DEMO1-COMMIT'
WHERE a.appointment_id = 8;

-- Expected: status=completed, one encounter, one diagnosis, one payment row.


-- =============================================================================
-- DEMO 2: ROLLBACK — Card capture fails mid-visit billing
-- Appointment may be completed clinically, but this demo rolls back the *billing*
-- transaction so a failed payment does not leave a completed payment row.
-- Variant shown: whole multi-step billing block aborts.
-- =============================================================================

BEGIN;

-- Attempt to record a pending payment then “discover” decline
INSERT INTO payment (
    patient_id, appointment_id, service_id, amount, method, status, paid_at, reference_no
) VALUES (
    1,
    7,                 -- PAT-1001 upcoming VI appointment
    1,                 -- SVC-CONS
    15000.00,
    'card',
    'pending',
    NOW(),
    'PAY-TX-DEMO2-FAIL'
);

-- Simulated payment gateway failure → abort unit of work
-- (In application code: catch decline, then ROLLBACK)
ROLLBACK;

-- Verification: reference must not exist
SELECT COUNT(*) AS should_be_zero
FROM payment
WHERE reference_no = 'PAY-TX-DEMO2-FAIL';

-- Expected: should_be_zero = 0


-- =============================================================================
-- DEMO 3: ROLLBACK on constraint violation — double-book same doctor slot
-- Schema constraint: UNIQUE (doctor_id, scheduled_at) AS uq_doctor_slot
-- =============================================================================

BEGIN;

-- First booking succeeds inside the transaction
INSERT INTO appointment (patient_id, doctor_id, branch_id, scheduled_at, duration_minutes, status, reason)
VALUES (3, 1, 1, TIMESTAMPTZ '2026-12-01 09:00:00+01', 30, 'booked', 'Demo slot A');

-- Second booking for SAME doctor + SAME timestamp → unique_violation
INSERT INTO appointment (patient_id, doctor_id, branch_id, scheduled_at, duration_minutes, status, reason)
VALUES (4, 1, 1, TIMESTAMPTZ '2026-12-01 09:00:00+01', 30, 'booked', 'Demo slot B — conflict');

-- PostgreSQL aborts the transaction on error; explicit ROLLBACK clears the aborted state
ROLLBACK;

-- Verification: neither demo row should remain if both were in the same aborted txn
SELECT COUNT(*) AS should_be_zero
FROM appointment
WHERE scheduled_at = TIMESTAMPTZ '2026-12-01 09:00:00+01'
  AND doctor_id = 1
  AND reason LIKE 'Demo slot%';

-- Expected: should_be_zero = 0
-- Note: if the first INSERT was committed separately, only the second would fail;
-- keeping both in one txn shows atomic all-or-nothing booking attempts.


-- =============================================================================
-- DEMO 4: SAVEPOINT — Keep appointment booking; undo only failed payment step
-- =============================================================================

BEGIN;

INSERT INTO appointment (patient_id, doctor_id, branch_id, scheduled_at, duration_minutes, status, reason)
VALUES (5, 3, 2, TIMESTAMPTZ '2026-12-02 10:30:00+01', 30, 'booked', 'Demo savepoint booking');

SAVEPOINT sp_before_payment;

INSERT INTO payment (
    patient_id, appointment_id, service_id, amount, method, status, paid_at, reference_no
)
SELECT 5, appointment_id, 2, 8000.00, 'card', 'pending', NOW(), 'PAY-TX-DEMO4'
FROM appointment
WHERE reason = 'Demo savepoint booking'
ORDER BY appointment_id DESC
LIMIT 1;

-- Simulated gateway decline → undo payment only
ROLLBACK TO SAVEPOINT sp_before_payment;

COMMIT;

SELECT
    (SELECT COUNT(*) FROM appointment WHERE reason = 'Demo savepoint booking') AS appt_kept,
    (SELECT COUNT(*) FROM payment WHERE reference_no = 'PAY-TX-DEMO4') AS pay_rolled_back;

-- Expected: appt_kept = 1, pay_rolled_back = 0


-- =============================================================================
-- DEMO 5: Idempotent payment completion (application pattern inside a txn)
-- Avoid double-charging if reception retries after a network timeout.
-- =============================================================================

BEGIN;

-- Only promote pending → completed if still pending
UPDATE payment
SET status = 'completed',
    paid_at = NOW()
WHERE reference_no = 'PAY-20261009-002'   -- seeded pending lab payment
  AND status = 'pending';

-- Second identical UPDATE in a retry would affect 0 rows (safe)
UPDATE payment
SET status = 'completed',
    paid_at = NOW()
WHERE reference_no = 'PAY-20261009-002'
  AND status = 'pending';

COMMIT;

SELECT reference_no, status, amount
FROM payment
WHERE reference_no = 'PAY-20261009-002';

-- Expected: single row, status=completed (not duplicated)


-- =============================================================================
-- DEMO 6: Isolation level switch (session settings for Portfolio 3 experiments)
-- Pair with narratives in Chibuzo_Miracle_Concurrency.md
-- =============================================================================

-- Session A example:
-- BEGIN ISOLATION LEVEL READ COMMITTED;
-- SELECT amount, status FROM payment WHERE payment_id = 9;
-- -- Session B updates/commits
-- SELECT amount, status FROM payment WHERE payment_id = 9;  -- sees committed change
-- COMMIT;

-- Session A example (stronger):
-- BEGIN ISOLATION LEVEL REPEATABLE READ;
-- SELECT amount, status FROM payment WHERE payment_id = 9;
-- -- Session B updates/commits
-- SELECT amount, status FROM payment WHERE payment_id = 9;  -- still sees snapshot
-- COMMIT;

-- Session A example (strictest commonly used):
-- BEGIN ISOLATION LEVEL SERIALIZABLE;
-- -- conflicting writes may raise: could not serialize access due to concurrent update
-- COMMIT;

-- End of Portfolio 3 transaction demos
