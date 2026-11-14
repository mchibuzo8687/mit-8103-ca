-- =============================================================================
-- CareLink Clinic — Relational Schema (Portfolio 1)
-- Document type: Schema
-- Student: Chibuzo Miracle (301888687)
-- File: Chibuzo_Miracle_Schema.sql
-- Engine target: PostgreSQL 14+
-- =============================================================================

-- Optional clean rebuild (comment out if appending to an existing DB)
DROP TABLE IF EXISTS payment CASCADE;
DROP TABLE IF EXISTS lab_order CASCADE;
DROP TABLE IF EXISTS lab_test CASCADE;
DROP TABLE IF EXISTS prescription CASCADE;
DROP TABLE IF EXISTS medication CASCADE;
DROP TABLE IF EXISTS diagnosis CASCADE;
DROP TABLE IF EXISTS encounter CASCADE;
DROP TABLE IF EXISTS appointment CASCADE;
DROP TABLE IF EXISTS service CASCADE;
DROP TABLE IF EXISTS patient CASCADE;
DROP TABLE IF EXISTS staff CASCADE;
DROP TABLE IF EXISTS specialty CASCADE;
DROP TABLE IF EXISTS branch CASCADE;

-- ---------------------------------------------------------------------------
-- Reference / master data
-- ---------------------------------------------------------------------------

CREATE TABLE branch (
    branch_id       SERIAL PRIMARY KEY,
    branch_code     VARCHAR(20)  NOT NULL,
    name            VARCHAR(120) NOT NULL,
    address_line1   VARCHAR(150) NOT NULL,
    city            VARCHAR(80)  NOT NULL,
    state           VARCHAR(80)  NOT NULL,
    phone           VARCHAR(30)  NOT NULL,
    email           VARCHAR(120),
    is_active       BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_branch_code UNIQUE (branch_code),
    CONSTRAINT ck_branch_email CHECK (email IS NULL OR email ~* '^[^@]+@[^@]+\.[^@]+$')
);

CREATE TABLE specialty (
    specialty_id    SERIAL PRIMARY KEY,
    specialty_code  VARCHAR(20)  NOT NULL,
    name            VARCHAR(100) NOT NULL,
    description     TEXT,
    CONSTRAINT uq_specialty_code UNIQUE (specialty_code),
    CONSTRAINT uq_specialty_name UNIQUE (name)
);

CREATE TABLE staff (
    staff_id        SERIAL PRIMARY KEY,
    branch_id       INTEGER      NOT NULL,
    specialty_id    INTEGER,                 -- required for doctors; optional otherwise
    staff_number    VARCHAR(30)  NOT NULL,
    role            VARCHAR(30)  NOT NULL,
    first_name      VARCHAR(80)  NOT NULL,
    last_name       VARCHAR(80)  NOT NULL,
    email           VARCHAR(120) NOT NULL,
    phone           VARCHAR(30),
    hire_date       DATE         NOT NULL DEFAULT CURRENT_DATE,
    is_active       BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_staff_number UNIQUE (staff_number),
    CONSTRAINT uq_staff_email UNIQUE (email),
    CONSTRAINT fk_staff_branch
        FOREIGN KEY (branch_id) REFERENCES branch (branch_id),
    CONSTRAINT fk_staff_specialty
        FOREIGN KEY (specialty_id) REFERENCES specialty (specialty_id),
    CONSTRAINT ck_staff_role CHECK (
        role IN ('doctor', 'nurse', 'lab', 'pharmacy', 'reception', 'manager')
    ),
    CONSTRAINT ck_staff_doctor_specialty CHECK (
        role <> 'doctor' OR specialty_id IS NOT NULL
    )
);

CREATE TABLE patient (
    patient_id      SERIAL PRIMARY KEY,
    patient_number  VARCHAR(30)  NOT NULL,
    first_name      VARCHAR(80)  NOT NULL,
    last_name       VARCHAR(80)  NOT NULL,
    date_of_birth   DATE         NOT NULL,
    gender          VARCHAR(20)  NOT NULL,
    phone           VARCHAR(30)  NOT NULL,
    email           VARCHAR(120),
    address_line1   VARCHAR(150),
    city            VARCHAR(80),
    emergency_name  VARCHAR(120),
    emergency_phone VARCHAR(30),
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_patient_number UNIQUE (patient_number),
    CONSTRAINT ck_patient_gender CHECK (
        gender IN ('female', 'male', 'other', 'prefer_not_to_say')
    ),
    CONSTRAINT ck_patient_dob CHECK (date_of_birth <= CURRENT_DATE),
    CONSTRAINT ck_patient_email CHECK (email IS NULL OR email ~* '^[^@]+@[^@]+\.[^@]+$')
);

CREATE TABLE medication (
    medication_id   SERIAL PRIMARY KEY,
    medication_code VARCHAR(30)  NOT NULL,
    name            VARCHAR(120) NOT NULL,
    form            VARCHAR(40)  NOT NULL,   -- tablet, syrup, injection, etc.
    strength        VARCHAR(40),
    CONSTRAINT uq_medication_code UNIQUE (medication_code)
);

CREATE TABLE lab_test (
    lab_test_id     SERIAL PRIMARY KEY,
    test_code       VARCHAR(30)  NOT NULL,
    name            VARCHAR(120) NOT NULL,
    specimen_type   VARCHAR(60)  NOT NULL,
    turnaround_hours INTEGER     NOT NULL DEFAULT 24,
    CONSTRAINT uq_lab_test_code UNIQUE (test_code),
    CONSTRAINT ck_lab_turnaround CHECK (turnaround_hours > 0)
);

CREATE TABLE service (
    service_id      SERIAL PRIMARY KEY,
    service_code    VARCHAR(30)  NOT NULL,
    name            VARCHAR(120) NOT NULL,
    unit_price      NUMERIC(12,2) NOT NULL,
    is_active       BOOLEAN      NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_service_code UNIQUE (service_code),
    CONSTRAINT ck_service_price CHECK (unit_price >= 0)
);

-- ---------------------------------------------------------------------------
-- Operational / transactional data
-- ---------------------------------------------------------------------------

CREATE TABLE appointment (
    appointment_id  SERIAL PRIMARY KEY,
    patient_id      INTEGER      NOT NULL,
    doctor_id       INTEGER      NOT NULL,
    branch_id       INTEGER      NOT NULL,
    scheduled_at    TIMESTAMPTZ  NOT NULL,
    duration_minutes INTEGER     NOT NULL DEFAULT 30,
    status          VARCHAR(20)  NOT NULL DEFAULT 'booked',
    reason          VARCHAR(255),
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_appt_patient
        FOREIGN KEY (patient_id) REFERENCES patient (patient_id),
    CONSTRAINT fk_appt_doctor
        FOREIGN KEY (doctor_id) REFERENCES staff (staff_id),
    CONSTRAINT fk_appt_branch
        FOREIGN KEY (branch_id) REFERENCES branch (branch_id),
    CONSTRAINT ck_appt_status CHECK (
        status IN ('booked', 'checked_in', 'completed', 'cancelled', 'no_show')
    ),
    CONSTRAINT ck_appt_duration CHECK (duration_minutes BETWEEN 10 AND 240),
    -- Prevent exact double-booking of the same doctor at the same timestamp
    CONSTRAINT uq_doctor_slot UNIQUE (doctor_id, scheduled_at)
);

CREATE TABLE encounter (
    encounter_id    SERIAL PRIMARY KEY,
    appointment_id  INTEGER      NOT NULL,
    patient_id      INTEGER      NOT NULL,
    doctor_id       INTEGER      NOT NULL,
    encounter_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    chief_complaint VARCHAR(255),
    clinical_notes  TEXT,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_encounter_appointment UNIQUE (appointment_id),
    CONSTRAINT fk_enc_appointment
        FOREIGN KEY (appointment_id) REFERENCES appointment (appointment_id),
    CONSTRAINT fk_enc_patient
        FOREIGN KEY (patient_id) REFERENCES patient (patient_id),
    CONSTRAINT fk_enc_doctor
        FOREIGN KEY (doctor_id) REFERENCES staff (staff_id)
);

CREATE TABLE diagnosis (
    diagnosis_id    SERIAL PRIMARY KEY,
    encounter_id    INTEGER      NOT NULL,
    icd_code        VARCHAR(20)  NOT NULL,
    description     VARCHAR(255) NOT NULL,
    severity        VARCHAR(20)  NOT NULL DEFAULT 'moderate',
    diagnosed_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_diag_encounter
        FOREIGN KEY (encounter_id) REFERENCES encounter (encounter_id) ON DELETE CASCADE,
    CONSTRAINT ck_diag_severity CHECK (
        severity IN ('mild', 'moderate', 'severe')
    )
);

CREATE TABLE prescription (
    prescription_id SERIAL PRIMARY KEY,
    encounter_id    INTEGER      NOT NULL,
    medication_id   INTEGER      NOT NULL,
    dosage          VARCHAR(80)  NOT NULL,
    frequency       VARCHAR(80)  NOT NULL,
    duration_days   INTEGER      NOT NULL,
    instructions    TEXT,
    status          VARCHAR(20)  NOT NULL DEFAULT 'active',
    prescribed_at   TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_rx_encounter
        FOREIGN KEY (encounter_id) REFERENCES encounter (encounter_id) ON DELETE CASCADE,
    CONSTRAINT fk_rx_medication
        FOREIGN KEY (medication_id) REFERENCES medication (medication_id),
    CONSTRAINT ck_rx_duration CHECK (duration_days > 0),
    CONSTRAINT ck_rx_status CHECK (
        status IN ('active', 'dispensed', 'cancelled', 'completed')
    )
);

CREATE TABLE lab_order (
    lab_order_id    SERIAL PRIMARY KEY,
    encounter_id    INTEGER      NOT NULL,
    lab_test_id     INTEGER      NOT NULL,
    status          VARCHAR(20)  NOT NULL DEFAULT 'ordered',
    ordered_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    resulted_at     TIMESTAMPTZ,
    result_text     TEXT,
    result_flag     VARCHAR(20),
    CONSTRAINT fk_labord_encounter
        FOREIGN KEY (encounter_id) REFERENCES encounter (encounter_id) ON DELETE CASCADE,
    CONSTRAINT fk_labord_test
        FOREIGN KEY (lab_test_id) REFERENCES lab_test (lab_test_id),
    CONSTRAINT ck_labord_status CHECK (
        status IN ('ordered', 'collected', 'in_progress', 'completed', 'cancelled')
    ),
    CONSTRAINT ck_labord_result_flag CHECK (
        result_flag IS NULL OR result_flag IN ('normal', 'abnormal', 'critical')
    ),
    CONSTRAINT ck_labord_result_time CHECK (
        resulted_at IS NULL OR resulted_at >= ordered_at
    )
);

CREATE TABLE payment (
    payment_id      SERIAL PRIMARY KEY,
    patient_id      INTEGER      NOT NULL,
    appointment_id  INTEGER,
    service_id      INTEGER      NOT NULL,
    amount          NUMERIC(12,2) NOT NULL,
    method          VARCHAR(20)  NOT NULL,
    status          VARCHAR(20)  NOT NULL DEFAULT 'completed',
    paid_at         TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    reference_no    VARCHAR(60),
    CONSTRAINT fk_pay_patient
        FOREIGN KEY (patient_id) REFERENCES patient (patient_id),
    CONSTRAINT fk_pay_appointment
        FOREIGN KEY (appointment_id) REFERENCES appointment (appointment_id),
    CONSTRAINT fk_pay_service
        FOREIGN KEY (service_id) REFERENCES service (service_id),
    CONSTRAINT uq_payment_reference UNIQUE (reference_no),
    CONSTRAINT ck_pay_amount CHECK (amount >= 0),
    CONSTRAINT ck_pay_method CHECK (
        method IN ('cash', 'card', 'transfer', 'insurance')
    ),
    CONSTRAINT ck_pay_status CHECK (
        status IN ('pending', 'completed', 'failed', 'refunded')
    )
);

-- ---------------------------------------------------------------------------
-- Helpful indexes for later Portfolio 2 work
-- ---------------------------------------------------------------------------

CREATE INDEX idx_staff_branch ON staff (branch_id);
CREATE INDEX idx_staff_role ON staff (role);
CREATE INDEX idx_appointment_patient ON appointment (patient_id);
CREATE INDEX idx_appointment_doctor_time ON appointment (doctor_id, scheduled_at);
CREATE INDEX idx_appointment_branch_time ON appointment (branch_id, scheduled_at);
CREATE INDEX idx_appointment_status ON appointment (status);
CREATE INDEX idx_encounter_patient ON encounter (patient_id);
CREATE INDEX idx_diagnosis_encounter ON diagnosis (encounter_id);
CREATE INDEX idx_prescription_encounter ON prescription (encounter_id);
CREATE INDEX idx_lab_order_encounter ON lab_order (encounter_id);
CREATE INDEX idx_payment_patient ON payment (patient_id);
CREATE INDEX idx_payment_paid_at ON payment (paid_at);

-- ---------------------------------------------------------------------------
-- Seed sample reference data (optional demo rows)
-- ---------------------------------------------------------------------------

INSERT INTO branch (branch_code, name, address_line1, city, state, phone, email) VALUES
('CL-IKE', 'CareLink Ikeja', '12 Allen Avenue', 'Ikeja', 'Lagos', '+2348010000001', 'ikeja@carelink.example'),
('CL-VI',  'CareLink Victoria Island', '5 Adeola Odeku Street', 'Victoria Island', 'Lagos', '+2348010000002', 'vi@carelink.example');

INSERT INTO specialty (specialty_code, name, description) VALUES
('GP', 'General Practice', 'Primary outpatient care'),
('PED', 'Paediatrics', 'Child and adolescent care'),
('CARD', 'Cardiology', 'Heart and circulatory conditions');

INSERT INTO staff (branch_id, specialty_id, staff_number, role, first_name, last_name, email, phone) VALUES
(1, 1, 'DOC-001', 'doctor', 'Ada', 'Okeke', 'ada.okeke@carelink.example', '+2348020000001'),
(1, 2, 'DOC-002', 'doctor', 'Tunde', 'Balogun', 'tunde.balogun@carelink.example', '+2348020000002'),
(2, 3, 'DOC-003', 'doctor', 'Ngozi', 'Eze', 'ngozi.eze@carelink.example', '+2348020000003'),
(1, NULL, 'REC-001', 'reception', 'Chioma', 'Umeh', 'chioma.umeh@carelink.example', '+2348020000004');

INSERT INTO patient (patient_number, first_name, last_name, date_of_birth, gender, phone, email, city) VALUES
('PAT-1001', 'Ibrahim', 'Sule', '1990-04-12', 'male', '+2348030000001', 'ibrahim.sule@example.com', 'Ikeja'),
('PAT-1002', 'Blessing', 'Ojo', '1985-11-03', 'female', '+2348030000002', 'blessing.ojo@example.com', 'Yaba');

INSERT INTO medication (medication_code, name, form, strength) VALUES
('MED-AMOX', 'Amoxicillin', 'capsule', '500mg'),
('MED-PARA', 'Paracetamol', 'tablet', '500mg');

INSERT INTO lab_test (test_code, name, specimen_type, turnaround_hours) VALUES
('LAB-FBC', 'Full Blood Count', 'blood', 6),
('LAB-MP',  'Malaria Parasite', 'blood', 4);

INSERT INTO service (service_code, name, unit_price) VALUES
('SVC-CONS', 'General Consultation', 15000.00),
('SVC-LAB',  'Laboratory Panel', 8000.00),
('SVC-FOL',  'Follow-up Visit', 10000.00);

-- End of Portfolio 1 schema
