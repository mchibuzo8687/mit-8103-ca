-- =============================================================================
-- CareLink Clinic — Indexing Recommendations (Portfolio 2)
-- Student: Chibuzo Miracle (301888687)
-- Dialect: PostgreSQL 14+
--
-- Portfolio 1 already created baseline indexes (see Schema.sql). This script
-- ADDS optimisation indexes targeting Portfolio 2 query predicates/joins.
-- Safe to re-run: uses IF NOT EXISTS.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- A. Confirm / reinforce Portfolio 1 baseline (idempotent)
-- ---------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_staff_branch ON staff (branch_id);
CREATE INDEX IF NOT EXISTS idx_staff_role ON staff (role);
CREATE INDEX IF NOT EXISTS idx_appointment_patient ON appointment (patient_id);
CREATE INDEX IF NOT EXISTS idx_appointment_doctor_time ON appointment (doctor_id, scheduled_at);
CREATE INDEX IF NOT EXISTS idx_appointment_branch_time ON appointment (branch_id, scheduled_at);
CREATE INDEX IF NOT EXISTS idx_appointment_status ON appointment (status);
CREATE INDEX IF NOT EXISTS idx_encounter_patient ON encounter (patient_id);
CREATE INDEX IF NOT EXISTS idx_diagnosis_encounter ON diagnosis (encounter_id);
CREATE INDEX IF NOT EXISTS idx_prescription_encounter ON prescription (encounter_id);
CREATE INDEX IF NOT EXISTS idx_lab_order_encounter ON lab_order (encounter_id);
CREATE INDEX IF NOT EXISTS idx_payment_patient ON payment (patient_id);
CREATE INDEX IF NOT EXISTS idx_payment_paid_at ON payment (paid_at);

-- ---------------------------------------------------------------------------
-- B. Additional indexes for Portfolio 2 workloads
-- ---------------------------------------------------------------------------

-- Q1 / daily schedule: filter by status after branch+time range
-- Partial index keeps only “live” statuses used on the schedule board
CREATE INDEX IF NOT EXISTS idx_appointment_live_schedule
    ON appointment (branch_id, scheduled_at)
    WHERE status IN ('booked', 'checked_in', 'completed');

-- Q3 / finance: join payment → appointment; filter completed + date
CREATE INDEX IF NOT EXISTS idx_payment_status_paid_at
    ON payment (status, paid_at);

CREATE INDEX IF NOT EXISTS idx_payment_appointment
    ON payment (appointment_id);

CREATE INDEX IF NOT EXISTS idx_payment_service
    ON payment (service_id);

-- Q5 / doctor workload: encounter by doctor; prescription join already covered
CREATE INDEX IF NOT EXISTS idx_encounter_doctor
    ON encounter (doctor_id);

-- Q6 / lab SLA: status filter + ordered_at ordering
CREATE INDEX IF NOT EXISTS idx_lab_order_status_ordered
    ON lab_order (status, ordered_at);

-- Q7 / pharmacy queue: active prescriptions by prescribed_at
CREATE INDEX IF NOT EXISTS idx_prescription_active_prescribed
    ON prescription (prescribed_at)
    WHERE status = 'active';

-- Q9 / clinical alerts: abnormal/critical results
CREATE INDEX IF NOT EXISTS idx_lab_order_abnormal
    ON lab_order (resulted_at DESC)
    WHERE result_flag IN ('abnormal', 'critical');

-- Supporting lookup: patient_number equality (history / pharmacy)
CREATE INDEX IF NOT EXISTS idx_patient_number
    ON patient (patient_number);

-- Supporting lookup: branch_code equality (schedule filters)
CREATE INDEX IF NOT EXISTS idx_branch_code
    ON branch (branch_code);

-- ---------------------------------------------------------------------------
-- C. Optional maintenance after bulk load
-- ---------------------------------------------------------------------------
-- ANALYZE appointment;
-- ANALYZE payment;
-- ANALYZE lab_order;
-- ANALYZE prescription;
-- ANALYZE encounter;

-- ---------------------------------------------------------------------------
-- D. How to inspect index usage (run after query workload)
-- ---------------------------------------------------------------------------
-- SELECT indexrelname, idx_scan, idx_tup_read, idx_tup_fetch
-- FROM pg_stat_user_indexes
-- WHERE schemaname = 'public'
-- ORDER BY idx_scan DESC;

-- End of Portfolio 2 indexes
