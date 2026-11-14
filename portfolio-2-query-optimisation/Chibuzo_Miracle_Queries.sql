-- =============================================================================
-- CareLink Clinic — Operational Queries (Portfolio 2)
-- Student: Chibuzo Miracle (301888687)
-- Prerequisite: Portfolio 1 schema + Chibuzo_Miracle_SeedData.sql
-- Each query includes a short purpose comment and an optional EXPLAIN form.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Q1: Daily branch schedule — who is booked today (or a given day)
-- Typical ops: reception whiteboard / doctor list for a branch
-- ---------------------------------------------------------------------------
-- EXPLAIN (ANALYZE, BUFFERS)
SELECT
    a.appointment_id,
    a.scheduled_at,
    a.status,
    a.reason,
    p.patient_number,
    p.first_name || ' ' || p.last_name AS patient_name,
    s.staff_number AS doctor_number,
    s.first_name || ' ' || s.last_name AS doctor_name,
    b.branch_code
FROM appointment a
JOIN patient p   ON p.patient_id = a.patient_id
JOIN staff s     ON s.staff_id = a.doctor_id
JOIN branch b    ON b.branch_id = a.branch_id
WHERE b.branch_code = 'CL-IKE'
  AND a.scheduled_at >= TIMESTAMPTZ '2026-11-10 00:00:00+01'
  AND a.scheduled_at <  TIMESTAMPTZ '2026-11-11 00:00:00+01'
  AND a.status IN ('booked', 'checked_in', 'completed')
ORDER BY a.scheduled_at;

-- ---------------------------------------------------------------------------
-- Q2: Patient cross-branch clinical history (appointments + diagnoses)
-- Typical ops: doctor reviewing returning patient across CareLink sites
-- ---------------------------------------------------------------------------
-- EXPLAIN (ANALYZE, BUFFERS)
SELECT
    p.patient_number,
    a.scheduled_at,
    a.status AS appointment_status,
    b.name AS branch_name,
    d.icd_code,
    d.description AS diagnosis,
    d.severity,
    enc.chief_complaint
FROM patient p
JOIN appointment a ON a.patient_id = p.patient_id
JOIN branch b      ON b.branch_id = a.branch_id
LEFT JOIN encounter enc ON enc.appointment_id = a.appointment_id
LEFT JOIN diagnosis d   ON d.encounter_id = enc.encounter_id
WHERE p.patient_number = 'PAT-1001'
ORDER BY a.scheduled_at DESC, d.diagnosis_id;

-- ---------------------------------------------------------------------------
-- Q3: Revenue by branch and payment method (aggregate report)
-- Typical ops: branch manager weekly finance summary
-- ---------------------------------------------------------------------------
-- EXPLAIN (ANALYZE, BUFFERS)
SELECT
    b.branch_code,
    b.name AS branch_name,
    pay.method,
    COUNT(*) AS payment_count,
    SUM(pay.amount) AS total_amount,
    ROUND(AVG(pay.amount), 2) AS avg_amount
FROM payment pay
JOIN appointment a ON a.appointment_id = pay.appointment_id
JOIN branch b      ON b.branch_id = a.branch_id
WHERE pay.status = 'completed'
  AND pay.paid_at >= TIMESTAMPTZ '2026-10-01 00:00:00+01'
  AND pay.paid_at <  TIMESTAMPTZ '2026-11-01 00:00:00+01'
GROUP BY b.branch_code, b.name, pay.method
ORDER BY b.branch_code, total_amount DESC;

-- ---------------------------------------------------------------------------
-- Q4: Outstanding / failed payments needing follow-up
-- Typical ops: reception finance chase list
-- ---------------------------------------------------------------------------
SELECT
    pay.payment_id,
    pay.reference_no,
    pay.amount,
    pay.method,
    pay.status,
    pay.paid_at,
    p.patient_number,
    p.first_name || ' ' || p.last_name AS patient_name,
    p.phone,
    svc.name AS service_name
FROM payment pay
JOIN patient p  ON p.patient_id = pay.patient_id
JOIN service svc ON svc.service_id = pay.service_id
WHERE pay.status IN ('pending', 'failed')
ORDER BY pay.paid_at;

-- ---------------------------------------------------------------------------
-- Q5: Doctor workload — completed encounters and Rx volume
-- Typical ops: capacity planning / specialty utilisation
-- ---------------------------------------------------------------------------
SELECT
    s.staff_number,
    s.first_name || ' ' || s.last_name AS doctor_name,
    sp.name AS specialty,
    b.branch_code,
    COUNT(DISTINCT enc.encounter_id) AS encounters_completed,
    COUNT(rx.prescription_id) AS prescriptions_issued
FROM staff s
JOIN specialty sp ON sp.specialty_id = s.specialty_id
JOIN branch b     ON b.branch_id = s.branch_id
LEFT JOIN encounter enc ON enc.doctor_id = s.staff_id
LEFT JOIN prescription rx ON rx.encounter_id = enc.encounter_id
WHERE s.role = 'doctor'
  AND s.is_active = TRUE
GROUP BY s.staff_number, s.first_name, s.last_name, sp.name, b.branch_code
ORDER BY encounters_completed DESC, prescriptions_issued DESC;

-- ---------------------------------------------------------------------------
-- Q6: Lab turnaround — completed orders with elapsed hours
-- Typical ops: lab supervisor SLA monitoring
-- ---------------------------------------------------------------------------
SELECT
    lo.lab_order_id,
    lt.test_code,
    lt.name AS test_name,
    lo.status,
    lo.ordered_at,
    lo.resulted_at,
    ROUND(EXTRACT(EPOCH FROM (lo.resulted_at - lo.ordered_at)) / 3600.0, 2) AS hours_elapsed,
    lt.turnaround_hours AS sla_hours,
    CASE
        WHEN lo.resulted_at IS NULL THEN 'open'
        WHEN EXTRACT(EPOCH FROM (lo.resulted_at - lo.ordered_at)) / 3600.0
             <= lt.turnaround_hours THEN 'within_sla'
        ELSE 'breached_sla'
    END AS sla_status,
    lo.result_flag
FROM lab_order lo
JOIN lab_test lt ON lt.lab_test_id = lo.lab_test_id
WHERE lo.status = 'completed'
ORDER BY hours_elapsed DESC;

-- ---------------------------------------------------------------------------
-- Q7: Active prescriptions awaiting dispense (pharmacy queue)
-- ---------------------------------------------------------------------------
SELECT
    rx.prescription_id,
    p.patient_number,
    p.first_name || ' ' || p.last_name AS patient_name,
    m.name AS medication,
    m.strength,
    rx.dosage,
    rx.frequency,
    rx.duration_days,
    rx.prescribed_at,
    doc.first_name || ' ' || doc.last_name AS prescribing_doctor
FROM prescription rx
JOIN medication m ON m.medication_id = rx.medication_id
JOIN encounter enc ON enc.encounter_id = rx.encounter_id
JOIN patient p ON p.patient_id = enc.patient_id
JOIN staff doc ON doc.staff_id = enc.doctor_id
WHERE rx.status = 'active'
ORDER BY rx.prescribed_at;

-- ---------------------------------------------------------------------------
-- Q8: No-show / cancellation rate by branch (quality metric)
-- ---------------------------------------------------------------------------
SELECT
    b.branch_code,
    COUNT(*) AS total_appointments,
    COUNT(*) FILTER (WHERE a.status = 'no_show') AS no_shows,
    COUNT(*) FILTER (WHERE a.status = 'cancelled') AS cancelled,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE a.status IN ('no_show', 'cancelled')) / COUNT(*),
        1
    ) AS pct_lost_slots
FROM appointment a
JOIN branch b ON b.branch_id = a.branch_id
GROUP BY b.branch_code
ORDER BY pct_lost_slots DESC;

-- ---------------------------------------------------------------------------
-- Q9: Patients with abnormal / critical lab results (clinical alert list)
-- ---------------------------------------------------------------------------
SELECT
    p.patient_number,
    p.first_name || ' ' || p.last_name AS patient_name,
    lt.test_code,
    lo.result_flag,
    lo.result_text,
    lo.resulted_at,
    doc.first_name || ' ' || doc.last_name AS ordering_doctor,
    b.branch_code
FROM lab_order lo
JOIN lab_test lt ON lt.lab_test_id = lo.lab_test_id
JOIN encounter enc ON enc.encounter_id = lo.encounter_id
JOIN patient p ON p.patient_id = enc.patient_id
JOIN staff doc ON doc.staff_id = enc.doctor_id
JOIN appointment a ON a.appointment_id = enc.appointment_id
JOIN branch b ON b.branch_id = a.branch_id
WHERE lo.result_flag IN ('abnormal', 'critical')
ORDER BY lo.resulted_at DESC;

-- ---------------------------------------------------------------------------
-- Q10: Top billable services by revenue (service catalogue utilisation)
-- ---------------------------------------------------------------------------
SELECT
    svc.service_code,
    svc.name,
    COUNT(pay.payment_id) AS times_billed,
    SUM(pay.amount) FILTER (WHERE pay.status = 'completed') AS completed_revenue,
    SUM(pay.amount) FILTER (WHERE pay.status = 'pending') AS pending_revenue
FROM service svc
LEFT JOIN payment pay ON pay.service_id = svc.service_id
WHERE svc.is_active = TRUE
GROUP BY svc.service_code, svc.name
ORDER BY completed_revenue DESC NULLS LAST;

-- End of Portfolio 2 queries
