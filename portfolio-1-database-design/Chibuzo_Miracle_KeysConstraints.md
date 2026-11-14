# CareLink Clinic — Keys and Constraints

**Document type:** KeysConstraints  
**Student:** Chibuzo Miracle (301888687)  
**DDL source:** [Chibuzo_Miracle_Schema.sql](Chibuzo_Miracle_Schema.sql)

This inventory maps primary keys, foreign keys, uniqueness rules, and CHECK constraints to CareLink business rules.

---

## 1. Primary Keys

| Table | Primary key | Purpose |
|-------|-------------|---------|
| branch | `branch_id` | Identifies each clinic location |
| specialty | `specialty_id` | Clinical specialty catalogue |
| staff | `staff_id` | Employees (doctors, nurses, admin, etc.) |
| patient | `patient_id` | Registered patients |
| medication | `medication_id` | Drug catalogue |
| lab_test | `lab_test_id` | Laboratory test catalogue |
| service | `service_id` | Billable service catalogue |
| appointment | `appointment_id` | Booked visit slots |
| encounter | `encounter_id` | Clinical visit record |
| diagnosis | `diagnosis_id` | Diagnosis line on an encounter |
| prescription | `prescription_id` | Prescribed medication line |
| lab_order | `lab_order_id` | Lab request / result |
| payment | `payment_id` | Payment transaction |

All PKs are `SERIAL` surrogates for stable joins; business codes are enforced separately with UNIQUE constraints.

---

## 2. Alternate / Unique Keys

| Table | Constraint | Business rule |
|-------|------------|---------------|
| branch | `uq_branch_code` | Stable branch code (e.g. `CL-IKE`) |
| specialty | `uq_specialty_code`, `uq_specialty_name` | No duplicate specialty codes or names |
| staff | `uq_staff_number`, `uq_staff_email` | HR number and login email unique |
| patient | `uq_patient_number` | Clinic MRN / patient number unique |
| medication | `uq_medication_code` | Formulary code unique |
| lab_test | `uq_lab_test_code` | Lab catalogue code unique |
| service | `uq_service_code` | Billing code unique |
| appointment | `uq_doctor_slot (doctor_id, scheduled_at)` | Same doctor cannot have two appointments at the exact same start time |
| encounter | `uq_encounter_appointment` | At most one encounter per appointment |
| payment | `uq_payment_reference` | Payment reference unique when supplied |

---

## 3. Foreign Keys

| Child table | Column(s) | References | On delete / notes |
|-------------|-----------|------------|-------------------|
| staff | `branch_id` | branch | Home branch required |
| staff | `specialty_id` | specialty | Optional except for doctors (see CHECK) |
| appointment | `patient_id` | patient | Who is booking |
| appointment | `doctor_id` | staff | Attending clinician |
| appointment | `branch_id` | branch | Where the visit occurs |
| encounter | `appointment_id` | appointment | Clinical record for a completed visit path |
| encounter | `patient_id` | patient | Denormalised FK for direct patient history queries (same patient as appointment) |
| encounter | `doctor_id` | staff | Clinician who conducted the encounter |
| diagnosis | `encounter_id` | encounter | `ON DELETE CASCADE` |
| prescription | `encounter_id` | encounter | `ON DELETE CASCADE` |
| prescription | `medication_id` | medication | Drug prescribed |
| lab_order | `encounter_id` | encounter | `ON DELETE CASCADE` |
| lab_order | `lab_test_id` | lab_test | Test ordered |
| payment | `patient_id` | patient | Payer / patient account |
| payment | `appointment_id` | appointment | Optional link to visit |
| payment | `service_id` | service | What was billed |

Cascade on clinical child rows (`diagnosis`, `prescription`, `lab_order`) keeps encounter deletion tidy in academic rebuilds; production systems may prefer soft-delete instead.

---

## 4. CHECK / Domain Constraints

| Table | Constraint | Rule enforced |
|-------|------------|---------------|
| branch | `ck_branch_email` | Email format when present |
| staff | `ck_staff_role` | Role ∈ doctor, nurse, lab, pharmacy, reception, manager |
| staff | `ck_staff_doctor_specialty` | Doctors must have `specialty_id` |
| patient | `ck_patient_gender` | Controlled gender vocabulary |
| patient | `ck_patient_dob` | Date of birth not in the future |
| patient | `ck_patient_email` | Email format when present |
| lab_test | `ck_lab_turnaround` | Turnaround hours > 0 |
| service | `ck_service_price` | Unit price ≥ 0 |
| appointment | `ck_appt_status` | booked / checked_in / completed / cancelled / no_show |
| appointment | `ck_appt_duration` | Duration between 10 and 240 minutes |
| diagnosis | `ck_diag_severity` | mild / moderate / severe |
| prescription | `ck_rx_duration` | Duration days > 0 |
| prescription | `ck_rx_status` | active / dispensed / cancelled / completed |
| lab_order | `ck_labord_status` | ordered → … → completed / cancelled |
| lab_order | `ck_labord_result_flag` | normal / abnormal / critical when set |
| lab_order | `ck_labord_result_time` | Result time not before ordered time |
| payment | `ck_pay_amount` | Amount ≥ 0 |
| payment | `ck_pay_method` | cash / card / transfer / insurance |
| payment | `ck_pay_status` | pending / completed / failed / refunded |

---

## 5. NOT NULL and Defaults (Selected)

- Operational timestamps (`created_at`, `paid_at`, `ordered_at`) default to `NOW()` where appropriate.  
- Appointment status defaults to `booked`; payment status defaults to `completed`.  
- Branch and staff `is_active` default to `TRUE` for soft lifecycle control.  
- Core identity fields (`name`, `phone` on patient, scheduled time on appointment) are `NOT NULL` so incomplete bookings cannot enter the database.

---

## 6. Indexes Supporting Constraints and Queries

Indexes on FK and filter columns (patient, doctor+time, branch+time, status, payment date) support referential checks and prepare Portfolio 2 optimisation work. See the index section at the end of `Chibuzo_Miracle_Schema.sql`.
