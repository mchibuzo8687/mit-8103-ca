-- =============================================================================
-- CareLink Clinic — Extended Seed Data (Portfolio 2)
-- Student: Chibuzo Miracle (301888687)
-- Prerequisite: ../portfolio-1-database-design/Chibuzo_Miracle_Schema.sql
-- Purpose: Enough appointments, encounters, labs, Rx, and payments for
--          meaningful joins, aggregates, and EXPLAIN demonstrations.
-- =============================================================================

-- Extra patients (Portfolio 1 already has PAT-1001, PAT-1002)
INSERT INTO patient (patient_number, first_name, last_name, date_of_birth, gender, phone, email, city) VALUES
('PAT-1003', 'Amaka', 'Nwosu', '1998-07-21', 'female', '+2348030000003', 'amaka.nwosu@example.com', 'Surulere'),
('PAT-1004', 'Chinedu', 'Okafor', '1978-02-14', 'male', '+2348030000004', 'chinedu.okafor@example.com', 'Ikeja'),
('PAT-1005', 'Fatima', 'Bello', '2001-09-30', 'female', '+2348030000005', 'fatima.bello@example.com', 'Victoria Island'),
('PAT-1006', 'Emeka', 'Ibe', '1965-12-01', 'male', '+2348030000006', 'emeka.ibe@example.com', 'Ikeja');

-- Extra staff for multi-branch scheduling
INSERT INTO staff (branch_id, specialty_id, staff_number, role, first_name, last_name, email, phone) VALUES
(2, 1, 'DOC-004', 'doctor', 'Yemi', 'Adeyemi', 'yemi.adeyemi@carelink.example', '+2348020000005'),
(1, NULL, 'LAB-001', 'lab', 'Ruth', 'Adebayo', 'ruth.adebayo@carelink.example', '+2348020000006'),
(1, NULL, 'PHARM-001', 'pharmacy', 'Kelechi', 'Nnaji', 'kelechi.nnaji@carelink.example', '+2348020000007');

INSERT INTO medication (medication_code, name, form, strength) VALUES
('MED-ATOR', 'Atorvastatin', 'tablet', '20mg'),
('MED-METF', 'Metformin', 'tablet', '500mg');

INSERT INTO lab_test (test_code, name, specimen_type, turnaround_hours) VALUES
('LAB-LFT', 'Liver Function Test', 'blood', 12),
('LAB-LIP', 'Lipid Profile', 'blood', 12);

-- Appointments across branches / statuses / dates
INSERT INTO appointment (patient_id, doctor_id, branch_id, scheduled_at, duration_minutes, status, reason) VALUES
(1, 1, 1, '2026-10-05 09:00:00+01', 30, 'completed', 'Fever and cough'),
(2, 1, 1, '2026-10-05 09:30:00+01', 30, 'completed', 'Follow-up hypertension'),
(3, 2, 1, '2026-10-06 10:00:00+01', 30, 'completed', 'Child vaccination review'),
(4, 3, 2, '2026-10-07 11:00:00+01', 45, 'completed', 'Chest pain assessment'),
(5, 3, 2, '2026-10-08 14:00:00+01', 30, 'completed', 'Palpitations'),
(6, 1, 1, '2026-10-09 09:00:00+01', 30, 'completed', 'Diabetes review'),
(1, 5, 2, '2026-11-10 09:00:00+01', 30, 'booked', 'General checkup'),  -- DOC-004 Yemi (VI)
(2, 1, 1, '2026-11-10 10:00:00+01', 30, 'booked', 'Blood pressure review'),
(3, 2, 1, '2026-11-11 11:00:00+01', 30, 'checked_in', 'Paediatric review'),
(4, 3, 2, '2026-11-12 15:00:00+01', 30, 'cancelled', 'Patient rescheduled'),
(5, 5, 2, '2026-11-13 09:30:00+01', 30, 'no_show', 'Missed slot'),       -- DOC-004
(6, 1, 1, '2026-11-14 08:30:00+01', 30, 'booked', 'Lab result discussion');

-- Encounters for completed appointments (1:1 with appointment)
INSERT INTO encounter (appointment_id, patient_id, doctor_id, encounter_at, chief_complaint, clinical_notes) VALUES
(1, 1, 1, '2026-10-05 09:05:00+01', 'Fever and cough', 'Suspected URTI; symptomatic care.'),
(2, 2, 1, '2026-10-05 09:35:00+01', 'Hypertension follow-up', 'BP controlled on current regimen.'),
(3, 3, 2, '2026-10-06 10:10:00+01', 'Vaccination review', 'Up to date; well child.'),
(4, 4, 3, '2026-10-07 11:10:00+01', 'Chest pain', 'Atypical chest pain; ECG advised.'),
(5, 5, 3, '2026-10-08 14:10:00+01', 'Palpitations', 'Sinus tachycardia; lifestyle advice.'),
(6, 6, 1, '2026-10-09 09:10:00+01', 'Diabetes review', 'Adjust metformin; order labs.');

INSERT INTO diagnosis (encounter_id, icd_code, description, severity) VALUES
(1, 'J06.9', 'Acute upper respiratory infection', 'mild'),
(2, 'I10', 'Essential (primary) hypertension', 'moderate'),
(3, 'Z00.1', 'Routine child health examination', 'mild'),
(4, 'R07.9', 'Chest pain, unspecified', 'moderate'),
(5, 'R00.0', 'Tachycardia, unspecified', 'mild'),
(6, 'E11.9', 'Type 2 diabetes mellitus without complications', 'moderate'),
(6, 'E78.5', 'Hyperlipidaemia, unspecified', 'mild');

-- medication_id: 1=Amoxicillin, 2=Paracetamol (P1); 3=Atorvastatin, 4=Metformin (this seed)
INSERT INTO prescription (encounter_id, medication_id, dosage, frequency, duration_days, instructions, status) VALUES
(1, 2, '500mg', 'every 6 hours', 3, 'Take after food', 'dispensed'),
(1, 1, '500mg', 'three times daily', 5, 'Complete course', 'dispensed'),
(2, 3, '20mg', 'once daily at night', 30, 'Continue indefinitely until review', 'active'),
(5, 2, '500mg', 'as needed', 3, 'Max 4g/day', 'completed'),
(6, 4, '500mg', 'twice daily', 30, 'With meals', 'active');

INSERT INTO lab_order (encounter_id, lab_test_id, status, ordered_at, resulted_at, result_text, result_flag) VALUES
(1, 1, 'completed', '2026-10-05 09:20:00+01', '2026-10-05 14:00:00+01', 'WBC 8.2; Hb 13.1; Plt 245', 'normal'),
(1, 2, 'completed', '2026-10-05 09:20:00+01', '2026-10-05 12:00:00+01', 'MP not seen', 'normal'),
(4, 1, 'completed', '2026-10-07 11:30:00+01', '2026-10-07 16:00:00+01', 'Mild anaemia Hb 11.2', 'abnormal'),
(4, 4, 'completed', '2026-10-07 11:30:00+01', '2026-10-07 18:00:00+01', 'LDL elevated 4.1 mmol/L', 'abnormal'),
(6, 3, 'completed', '2026-10-09 09:30:00+01', '2026-10-09 18:00:00+01', 'ALT 28; AST 24', 'normal'),
(6, 4, 'in_progress', '2026-10-09 09:30:00+01', NULL, NULL, NULL),
(5, 1, 'ordered', '2026-10-08 14:30:00+01', NULL, NULL, NULL);

INSERT INTO payment (patient_id, appointment_id, service_id, amount, method, status, paid_at, reference_no) VALUES
(1, 1, 1, 15000.00, 'card', 'completed', '2026-10-05 09:00:00+01', 'PAY-20261005-001'),
(1, 1, 2, 8000.00, 'card', 'completed', '2026-10-05 09:25:00+01', 'PAY-20261005-002'),
(2, 2, 3, 10000.00, 'cash', 'completed', '2026-10-05 09:30:00+01', 'PAY-20261005-003'),
(3, 3, 1, 15000.00, 'transfer', 'completed', '2026-10-06 10:00:00+01', 'PAY-20261006-001'),
(4, 4, 1, 15000.00, 'insurance', 'completed', '2026-10-07 11:00:00+01', 'PAY-20261007-001'),
(4, 4, 2, 8000.00, 'insurance', 'completed', '2026-10-07 11:35:00+01', 'PAY-20261007-002'),
(5, 5, 1, 15000.00, 'card', 'completed', '2026-10-08 14:00:00+01', 'PAY-20261008-001'),
(6, 6, 1, 15000.00, 'cash', 'completed', '2026-10-09 09:00:00+01', 'PAY-20261009-001'),
(6, 6, 2, 8000.00, 'cash', 'pending', '2026-10-09 09:40:00+01', 'PAY-20261009-002'),
(1, 7, 1, 15000.00, 'card', 'pending', '2026-11-10 08:50:00+01', 'PAY-20261110-001'),
(2, 8, 3, 10000.00, 'transfer', 'failed', '2026-11-10 09:55:00+01', 'PAY-20261110-002');

-- End of Portfolio 2 seed data
