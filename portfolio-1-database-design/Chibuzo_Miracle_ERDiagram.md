# CareLink Clinic — Entity-Relationship Diagram

**Document type:** ERDiagram  
**Student:** Chibuzo Miracle (301888687)  
**File:** `Chibuzo_Miracle_ERDiagram.md`

## 1. Conceptual Overview

Core entities: **Branch**, **Staff**, **Patient**, **Specialty**, **Appointment**, **Encounter**, **Diagnosis**, **Medication**, **Prescription**, **LabTest**, **LabOrder**, **Service**, **Payment**.

Key relationships:

- A **Branch** employs many **Staff** and hosts many **Appointments**.  
- A **Doctor** (Staff) has one **Specialty** and many **Appointments**.  
- A **Patient** books many **Appointments**.  
- An **Appointment** may produce one **Encounter**.  
- An **Encounter** may have many **Diagnoses**, **Prescriptions**, and **LabOrders**.  
- A **Payment** references a **Patient**, optional **Appointment**, and a **Service**.

## 2. Mermaid ER Diagram

```mermaid
erDiagram
    BRANCH ||--o{ STAFF : employs
    BRANCH ||--o{ APPOINTMENT : hosts
    SPECIALTY ||--o{ STAFF : qualifies
    STAFF ||--o{ APPOINTMENT : "doctor schedules"
    PATIENT ||--o{ APPOINTMENT : books
    PATIENT ||--o{ PAYMENT : makes
    APPOINTMENT ||--o| ENCOUNTER : generates
    APPOINTMENT ||--o{ PAYMENT : "may bill"
    ENCOUNTER ||--o{ DIAGNOSIS : records
    ENCOUNTER ||--o{ PRESCRIPTION : issues
    ENCOUNTER ||--o{ LAB_ORDER : requests
    MEDICATION ||--o{ PRESCRIPTION : "prescribed as"
    LAB_TEST ||--o{ LAB_ORDER : "ordered as"
    SERVICE ||--o{ PAYMENT : charges

    BRANCH {
        int branch_id PK
        string branch_code UK
        string name
        string city
        string phone
    }

    SPECIALTY {
        int specialty_id PK
        string specialty_code UK
        string name
    }

    STAFF {
        int staff_id PK
        int branch_id FK
        int specialty_id FK
        string staff_number UK
        string role
        string first_name
        string last_name
        string email UK
    }

    PATIENT {
        int patient_id PK
        string patient_number UK
        string first_name
        string last_name
        date date_of_birth
        string gender
        string phone
        string email
    }

    APPOINTMENT {
        int appointment_id PK
        int patient_id FK
        int doctor_id FK
        int branch_id FK
        datetime scheduled_at
        string status
        string reason
    }

    ENCOUNTER {
        int encounter_id PK
        int appointment_id FK UK
        int patient_id FK
        int doctor_id FK
        datetime encounter_at
        text clinical_notes
    }

    DIAGNOSIS {
        int diagnosis_id PK
        int encounter_id FK
        string icd_code
        string description
        string severity
    }

    MEDICATION {
        int medication_id PK
        string medication_code UK
        string name
        string form
    }

    PRESCRIPTION {
        int prescription_id PK
        int encounter_id FK
        int medication_id FK
        string dosage
        string frequency
        int duration_days
        string status
    }

    LAB_TEST {
        int lab_test_id PK
        string test_code UK
        string name
        string specimen_type
    }

    LAB_ORDER {
        int lab_order_id PK
        int encounter_id FK
        int lab_test_id FK
        string status
        text result_text
        datetime resulted_at
    }

    SERVICE {
        int service_id PK
        string service_code UK
        string name
        decimal unit_price
    }

    PAYMENT {
        int payment_id PK
        int patient_id FK
        int appointment_id FK
        int service_id FK
        decimal amount
        string method
        string status
        datetime paid_at
    }
```

## 3. Cardinality Notes

| Relationship | Cardinality | Business rule |
|--------------|-------------|----------------|
| Branch–Staff | 1:N | Each staff member has a home branch |
| Specialty–Staff | 1:N | Doctors reference a specialty; non-clinical staff may leave specialty NULL |
| Patient–Appointment | 1:N | A patient may have many appointments |
| Staff–Appointment | 1:N | A doctor has many appointments |
| Appointment–Encounter | 1:0..1 | At most one clinical encounter per appointment |
| Encounter–Diagnosis | 1:N | Multiple diagnoses allowed per visit |
| Encounter–Prescription | 1:N | Multiple medications per encounter |
| Encounter–LabOrder | 1:N | Multiple lab orders per encounter |
| Patient–Payment | 1:N | Payment history per patient |

## 4. Design Decisions

- **Encounter** is separated from **Appointment** so cancelled/no-show appointments do not invent clinical records.  
- **Prescription** and **LabOrder** hang off **Encounter**, not directly off **Appointment**, reflecting clinical workflow.  
- **Payment** can optionally link to an appointment for visit billing while remaining queryable by patient alone.
