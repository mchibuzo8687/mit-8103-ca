# CareLink Clinic — Normalisation Explanation

**Document type:** Normalisation  
**Student:** Chibuzo Miracle (301888687)  
**Schema reference:** [Chibuzo_Miracle_Schema.sql](Chibuzo_Miracle_Schema.sql)

This document shows how the CareLink relational design reaches **Third Normal Form (3NF)**, with a short note on **BCNF**. Examples use attributes from the implemented schema.

---

## 1. Why Normalisation Matters Here

Clinic data mixes master records (patients, staff, medications) with transactional events (appointments, encounters, payments). Without normalisation, reception and clinical workflows would duplicate demographics, specialty names, and drug catalogues inside every appointment or prescription row — causing update anomalies and inconsistent billing.

---

## 2. Starting Point: An Unnormalised Booking Record

Imagine a single “flat” booking sheet used before design:

| patient_name | patient_phone | doctor_name | specialty_name | branch_name | branch_city | scheduled_at | med1_name | med1_dose | med2_name | med2_dose | service_name | amount |
|--------------|---------------|-------------|----------------|-------------|-------------|--------------|-----------|-----------|-----------|-----------|--------------|--------|
| Ibrahim Sule | +234…001 | Ada Okeke | General Practice | CareLink Ikeja | Ikeja | 2026-11-20 09:00 | Amoxicillin | 500mg TDS | Paracetamol | 1g TDS | Consultation | 15000 |

Problems in this structure:

- **Repeating medication groups** (med1_*, med2_*) → not even 1NF  
- **Patient phone** repeated on every visit → update anomaly if the patient changes number  
- **Specialty name** stored with every appointment → inconsistent spelling across rows  
- **Service price** could drift from a catalogue price if embedded only in payment text  

---

## 3. First Normal Form (1NF)

**Rule:** Atomic attributes; no repeating groups; each row uniquely identifiable.

### Transformation

- Split repeating medications into separate **prescription** rows.  
- Keep one value per cell (no comma-lists of diagnoses or phone numbers as multi-value packs).  
- Introduce surrogate keys (`patient_id`, `appointment_id`, …) plus business keys (`patient_number`, …).

### CareLink example (1NF-compliant fragment)

**appointment**

| appointment_id | patient_id | doctor_id | branch_id | scheduled_at | status |
|----------------|------------|-----------|-----------|--------------|--------|
| 1 | 1 | 1 | 1 | 2026-11-20 09:00 | booked |

**prescription** (one row per drug — no med1/med2 columns)

| prescription_id | encounter_id | medication_id | dosage | frequency | duration_days |
|-----------------|--------------|---------------|--------|-----------|---------------|
| 1 | 10 | 1 | 500mg | TDS | 7 |
| 2 | 10 | 2 | 1g | TDS | 3 |

**Result:** All relations in the schema are in **1NF**.

---

## 4. Second Normal Form (2NF)

**Rule:** Already in 1NF; every non-key attribute depends on the **whole** primary key (no partial dependency on part of a composite key).

### Illustrating a 2NF violation (rejected design)

Suppose prescriptions used a composite key `(encounter_id, medication_id)` and also stored `medication_name` and `medication_form` on the same row:

| encounter_id (PK) | medication_id (PK) | medication_name | medication_form | dosage |
|-------------------|--------------------|-----------------|-----------------|--------|
| 10 | 1 | Amoxicillin | capsule | 500mg |

Here `medication_name` and `medication_form` depend only on `medication_id`, not on the full composite key → **partial dependency** → not 2NF.

### CareLink correction

- **medication** holds `name`, `form`, `strength` keyed by `medication_id`.  
- **prescription** holds only prescribing facts (`dosage`, `frequency`, `duration_days`, `status`) keyed by `prescription_id`, with FKs to `encounter` and `medication`.

Similarly, `branch.city` is not stored on `appointment`; appointments reference `branch_id` only.

**Result:** Relations with composite natural meanings are decomposed so non-key attributes depend on the full PK → **2NF**.

---

## 5. Third Normal Form (3NF)

**Rule:** Already in 2NF; no **transitive** dependency of a non-key attribute on the primary key via another non-key attribute.

### Illustrating a 3NF violation (rejected design)

Staff table with specialty denormalised:

| staff_id (PK) | first_name | specialty_id | specialty_name | specialty_description |
|---------------|------------|--------------|----------------|------------------------|
| 1 | Ada | 1 | General Practice | Primary outpatient care |

Dependencies:

- `staff_id → specialty_id`  
- `specialty_id → specialty_name, specialty_description`  

Therefore `staff_id → specialty_name` **transitively**. Changing the specialty description would require updating every doctor row.

### CareLink correction

```text
staff(staff_id, branch_id, specialty_id, staff_number, role, first_name, ...)
specialty(specialty_id, specialty_code, name, description)
```

`specialty_name` lives only in **specialty**. Staff stores `specialty_id` (nullable for non-doctors; CHECK enforces doctors must have a specialty).

### Another 3NF example: payments vs services

Rejected: store `service_name` and a hard-coded catalogue meaning only inside payment history without a service table, while also keeping a mutable “current price” on the payment row mixed with catalogue identity.

CareLink approach:

- **service** — catalogue (`service_code`, `name`, `unit_price`)  
- **payment** — transaction (`amount`, `method`, `status`, `paid_at`) with `service_id` FK  

The amount charged on a payment is a **fact of that transaction** (may differ from today’s catalogue price after a promotion or fee change). Catalogue attributes (`name`, current `unit_price`) are not transitively pulled through `payment_id` via duplicated service text fields.

### Patient demographics

`patient.phone` / `email` depend on `patient_id` only. Appointments and encounters reference `patient_id`; they do not repeat demographics → no transitive patient-detail dependency through `appointment_id`.

**Result:** The implemented schema is in **3NF**.

---

## 6. Brief BCNF Note

**Boyce–Codd Normal Form** strengthens 3NF: every determinant of a functional dependency must be a candidate key.

CareLink design choices that support BCNF in practice:

| Relation | Candidate keys / determinants | Notes |
|----------|-------------------------------|--------|
| branch | `branch_id`; also `branch_code` | UNIQUE on `branch_code` |
| staff | `staff_id`; also `staff_number`, `email` | Role/specialty rule via CHECK, not a conflicting FD |
| appointment | `appointment_id`; also `(doctor_id, scheduled_at)` | UNIQUE prevents double-booking; both keys determine the row |
| encounter | `encounter_id`; also `appointment_id` | 1:1 with appointment |

No non-key attribute is used as a determinant for other non-key attributes in the final tables. The schema is therefore consistent with **BCNF** for the modelled FDs.

---

## 7. Normalisation Trace Summary

| Form | What we removed | CareLink evidence |
|------|-----------------|-------------------|
| 1NF | Repeating med/diagnosis groups | Separate `prescription`, `diagnosis`, `lab_order` tables |
| 2NF | Partial deps on composite keys | Drug catalogue attributes moved to `medication` |
| 3NF | Transitive deps via non-keys | `specialty`, `branch`, `service`, `patient` as independent masters |
| BCNF | Determinants that are not keys | Business uniques (`branch_code`, doctor slot) declared as keys/UNIQUE |

---

## 8. Keys and Constraints (Linked to Normalisation)

Normal forms are enforced in PostgreSQL by:

- **Primary keys** on every table  
- **UNIQUE** business keys (`patient_number`, `staff_number`, `uq_doctor_slot`, …)  
- **FOREIGN KEYS** implementing relationships without duplicating parent attributes  
- **CHECK** constraints for domains (`role`, `status`, doctor-must-have-specialty)  

Full DDL: [Chibuzo_Miracle_Schema.sql](Chibuzo_Miracle_Schema.sql). Narrative inventory: [Chibuzo_Miracle_KeysConstraints.md](Chibuzo_Miracle_KeysConstraints.md).
