# CareLink Clinic — Case Study Statement

**Document type:** CaseStudy  
**Student:** Chibuzo Miracle (301888687)  
**File:** `Chibuzo_Miracle_CaseStudy.md`

## 1. Organisation Name / Scenario

**CareLink Clinic** is a simulated private outpatient healthcare network operating multiple branches in an urban region. It is not a tertiary (inpatient) hospital: care is appointment-driven, with same-day walk-ins handled as a limited capacity stream.

## 2. Nature of the Business / System

CareLink provides:

- Patient registration and demographic maintenance  
- Multi-branch doctor scheduling and appointment booking  
- Clinical encounters (consultation notes and diagnoses)  
- Prescriptions and pharmacy dispensing records  
- Laboratory test orders and results  
- Billing and payment recording for services rendered  

The system must support day-to-day clinic operations while preserving a consistent patient record across branches.

## 3. Users of the Database

| Role | Typical use |
|------|-------------|
| Reception / front desk | Register patients, book/cancel/reschedule appointments, take payments |
| Doctors | View schedule, record encounters, issue diagnoses and prescriptions, order labs |
| Nurses | Support triage notes, prepare patients, update encounter status |
| Laboratory staff | Receive orders, record results |
| Pharmacists | Dispense prescribed medications |
| Branch managers | Review capacity, staff assignment, revenue summaries |
| Patients (limited) | View own appointments and basic history (future self-service channel) |

## 4. Major Data to Be Stored

- **Branches** — location, contact, operating hours  
- **Staff** — doctors, nurses, lab/pharmacy/admin staff and their branch assignments  
- **Patients** — demographics, contact details, emergency contact  
- **Specialties** — clinical specialties linked to doctors  
- **Appointments** — booked slots, status, branch, doctor, patient  
- **Encounters** — visit records linked to appointments  
- **Diagnoses** — coded diagnoses per encounter  
- **Medications & prescriptions** — prescribed items and dispensing status  
- **Lab tests** — catalogue, orders, and results  
- **Services & payments** — billable services and payment transactions  

## 5. Key Operations the Database Will Support

1. Register a new patient (or update demographics)  
2. Assign staff to a branch and specialty (for doctors)  
3. Book, cancel, or complete an appointment  
4. Record a clinical encounter and diagnoses  
5. Issue a prescription and track dispense status  
6. Order laboratory tests and store results  
7. Record service charges and payments  
8. Retrieve a patient’s cross-branch history (appointments, encounters, labs, prescriptions)

## 6. Why This Case Study Fits Later Portfolios

| Portfolio | Fit |
|-----------|-----|
| 2 — Query / optimisation | Busy appointment and history queries; indexes on dates, patient_id, doctor_id |
| 3 — Transactions / concurrency | Double-booking prevention; payment + appointment status updates |
| 4 — NoSQL | Document store for flexible clinical notes / longitudinal patient history |
| 5 — Distributed / cloud | Multi-branch replication, availability, and consistency trade-offs |

## 7. Scope Boundary

Out of scope for Portfolio 1 (may appear later as discussion only): full EHR interoperability standards, imaging PACS, insurance claims adjudication engines, and mobile app UI.
