# CareLink Clinic — NoSQL and Advanced Data Models

**Document type:** NoSQL_Model  
**Student:** Chibuzo Miracle (301888687)  
**File:** `Chibuzo_Miracle_NoSQL_Model.md`  
**Course:** MIT 8103 Advanced Database Systems — Portfolio 4  
**Case study:** CareLink Clinic (same entities as Portfolio 1)

## 1. Purpose

Portfolio 1 modelled CareLink as a normalised PostgreSQL schema (Branch, Specialty, Staff, Patient, Appointment, Encounter, Diagnosis, Medication, Prescription, LabTest, LabOrder, Service, Payment). That design is correct for transactional integrity: unique doctor slots, payment amounts, and referential links.

Portfolio 4 shows where **polyglot persistence** helps CareLink without discarding the relational core. Three NoSQL paradigms are applied to distinct operational pressure points:

| Paradigm | Store (example) | CareLink use case |
|----------|-----------------|-------------------|
| Document | MongoDB | Longitudinal patient chart: encounter + diagnoses + prescriptions + labs as one readable aggregate |
| Key–value | Redis | Hot appointment-slot inventory and short-lived staff session / check-in state |
| Graph | Neo4j (conceptual) | Referral and coverage network across doctors, specialties, and branches |

Implementation evidence: `Chibuzo_Miracle_MongoDocuments.json`, `Chibuzo_Miracle_NoSQL_Queries.js`, `Chibuzo_Miracle_Redis_KeyValue.md`.

---

## 2. Hybrid architecture (relational + NoSQL)

```text
                    ┌─────────────────────────────┐
                    │  CareLink application APIs  │
                    └──────────────┬──────────────┘
           ┌───────────────────────┼───────────────────────┐
           ▼                       ▼                       ▼
   PostgreSQL (P1)           MongoDB                  Redis
   source of truth           clinical document        slots / sessions
   appointments,             patient chart            TTL check-in
   payments, staff,          encounter aggregates
   catalogue tables
           │
           └──────── optional Neo4j: referral / network analytics
```

**Design rule:** Money, booking uniqueness, and master catalogues stay relational. Flexible clinical narratives and high-churn cache state move to NoSQL.

---

## 3. Document model (MongoDB)

### 3.1 Why documents fit clinical work

A CareLink visit is naturally an **aggregate**: one appointment becomes one encounter that may carry several diagnoses, prescriptions, and lab orders. In PostgreSQL that is five–six tables and joins. Doctors and nurses usually want the **whole visit** (and a recent timeline) in one screen.

Document stores suit:

- Semi-structured **clinical notes** (SOAP sections, vitals that vary by specialty)
- Evolving observation fields without ALTER TABLE on every clinic form change
- **Patient longitudinal history** read as an ordered list of visit documents

### 3.2 Collections and mapping from Portfolio 1

| MongoDB collection | Relational source | Modelling choice |
|--------------------|-------------------|------------------|
| `patients` | `patient` | Demographics document; `patientNumber` mirrors `patient_number` |
| `encounters` | `encounter` + nested `diagnosis`, `prescription`, `lab_order` | **Embedded** clinical children loaded with the visit |
| `medications` / `labTests` (optional) | `medication`, `lab_test` | Keep as reference docs **or** leave catalogue in PostgreSQL and denormalise codes into the encounter |

**Embedding rationale:** Diagnoses, prescriptions, and lab results for a visit are accessed together and have a clear parent (`encounter`). Their lifecycle is subordinate to the encounter (Portfolio 1 uses `ON DELETE CASCADE` for these children).

**What stays relational:** `appointment` booking with `UNIQUE (doctor_id, scheduled_at)`, `payment`, `service` prices, and staff payroll assignment — these need strong ACID and cross-row constraints MongoDB does not replace.

### 3.3 Suggested document schemas

**`patients`**

```javascript
{
  _id: ObjectId,
  patientNumber: String,      // PAT-1001 — same as P1
  firstName: String,
  lastName: String,
  dateOfBirth: Date,
  gender: String,
  phone: String,
  email: String,
  address: { line1: String, city: String },
  emergency: { name: String, phone: String },
  preferredBranchCode: String, // CL-IKE | CL-VI
  createdAt: Date,
  updatedAt: Date
}
```

**`encounters` (aggregate root for a completed visit)**

```javascript
{
  _id: ObjectId,
  encounterKey: String,       // ENC-... business key
  appointmentId: Number,      // FK-style link back to PostgreSQL appointment
  patientNumber: String,
  doctor: {
    staffNumber: String,
    name: String,
    specialtyCode: String
  },
  branch: { branchCode: String, name: String },
  encounterAt: Date,
  chiefComplaint: String,
  clinicalNotes: {
    subjective: String,
    objective: String,
    assessment: String,
    plan: String,
    vitals: {                 // flexible — paeds vs cardiology differ
      bpSystolic: Number,
      bpDiastolic: Number,
      pulse: Number,
      tempC: Number,
      weightKg: Number,
      spo2: Number
    },
    extraObservations: Mixed  // specialty-specific fields
  },
  diagnoses: [
    { icdCode: String, description: String, severity: String, diagnosedAt: Date }
  ],
  prescriptions: [
    {
      medicationCode: String,
      medicationName: String,
      dosage: String,
      frequency: String,
      durationDays: Number,
      instructions: String,
      status: String
    }
  ],
  labOrders: [
    {
      testCode: String,
      testName: String,
      status: String,
      orderedAt: Date,
      resultedAt: Date,
      resultText: String,
      resultFlag: String,
      resultValues: Mixed     // structured panels when available
    }
  ],
  createdAt: Date
}
```

Indexes (see query script): `patientNumber + encounterAt`, `appointmentId` (unique), text index on notes for clinical search.

### 3.4 Suitability vs relational (document layer)

| Concern | Prefer PostgreSQL | Prefer MongoDB documents |
|---------|-------------------|---------------------------|
| Prevent double-booking | Yes — unique slot constraint | No — race-prone without careful transactions |
| Bill payment / refunds | Yes — numeric integrity, FKs | No |
| Full visit chart for one patient | Many joins | Single document or short timeline query |
| Add new vital / form field mid-year | Schema migration | New fields in `clinicalNotes` |
| Cross-patient revenue reports | SQL aggregations | Possible but awkward; leave in RDBMS |

---

## 4. Key–value model (Redis)

### 4.1 Why key–value fits booking pressure

Reception at CareLink Ikeja and Victoria Island repeatedly asks: “Which slots are free for Dr Okeke this afternoon?” Hitting PostgreSQL for every calendar paint is wasteful. Redis holds **derived, time-bounded** state with O(1) / O(log N) access and TTL.

### 4.2 Key patterns

| Key pattern | Type | Purpose |
|-------------|------|---------|
| `slot:{branchCode}:{staffNumber}:{yyyyMMddHHmm}` | String (`booked` / `held`) | Slot occupancy cache aligned with P1 `appointment` |
| `doctor:day:{staffNumber}:{yyyyMMdd}` | Set of HHMM | Free or booked minute marks for a doctor-day |
| `hold:{token}` | Hash | Temporary hold while reception confirms patient details |
| `session:staff:{token}` | Hash + TTL | Authenticated staff session |
| `checkin:{appointmentId}` | String + TTL | Patient checked in; expires if abandoned |

Detailed commands and examples: `Chibuzo_Miracle_Redis_KeyValue.md`.

### 4.3 Suitability vs relational (key–value)

Redis is a **cache / coordination** layer, not the system of record. On restart or cache miss, slots rebuild from PostgreSQL `appointment`. Holds use short TTLs so abandoned bookings release capacity. Payments and final `booked` status still commit in PostgreSQL (Portfolio 3 concurrency concerns).

---

## 5. Graph model (Neo4j) — referral / coverage network

### 5.1 Why a graph helps

CareLink patients sometimes need **internal referrals** (GP → Cardiology) or coverage when a doctor is unavailable at another branch. Relational tables can store `referral(from_staff, to_staff, specialty)`, but multi-hop questions (“who within two hops can cover Paediatrics near Victoria Island?”) are clearer as graph traversals.

### 5.2 Example property graph

```cypher
// Node labels map to P1 entities
(:Branch {branchCode:'CL-IKE', name:'CareLink Ikeja'})
(:Specialty {specialtyCode:'CARD', name:'Cardiology'})
(:Staff {staffNumber:'DOC-001', role:'doctor', name:'Ada Okeke'})
(:Patient {patientNumber:'PAT-1001'})

// Relationships
(:Staff)-[:WORKS_AT]->(:Branch)
(:Staff)-[:HAS_SPECIALTY]->(:Specialty)
(:Staff)-[:REFERS_TO {reason:'cardiac follow-up'}]->(:Staff)
(:Patient)-[:SEEN_BY]->(:Staff)
```

Sample analytic query:

```cypher
MATCH (p:Patient {patientNumber:'PAT-1001'})-[:SEEN_BY]->(gp:Staff)
      -[:REFERS_TO*1..2]->(spec:Staff)-[:HAS_SPECIALTY]->(s:Specialty {specialtyCode:'CARD'})
RETURN spec.name, s.name
```

### 5.3 Suitability vs relational (graph)

Use Neo4j (or keep referral edges in SQL until volume justifies a graph) for **network analytics and care-path discovery**. Do not move appointments or payments into the graph as primary storage.

---

## 6. Consistency and synchronisation notes

1. **Write path (booking):** validate slot in Redis hold → insert `appointment` in PostgreSQL → mark Redis slot `booked`.  
2. **Write path (clinical):** complete encounter in PostgreSQL (or dual-write) → upsert MongoDB `encounters` document for read-optimised chart.  
3. **Identifiers:** reuse Portfolio 1 business keys (`patient_number`, `staff_number`, `branch_code`, medication/test codes) so stores stay joinable conceptually without shared ObjectIds.  
4. **Conflict rule:** if MongoDB chart and PostgreSQL diverge, **PostgreSQL wins** for structured facts; MongoDB may hold richer narrative fields not yet modelled in SQL.

---

## 7. Summary judgment for MIT 8103

CareLink should remain a **hybrid** system:

- **Relational** — transactional backbone (Portfolio 1–3).  
- **Document** — flexible, patient-centred clinical aggregates.  
- **Key–value** — low-latency scheduling and session state.  
- **Graph** — optional referral/coverage intelligence.

This matches the case study’s later-portfolio note: “Document store for flexible clinical notes / longitudinal patient history,” while showing two further paradigms that map cleanly to multi-branch outpatient operations.
