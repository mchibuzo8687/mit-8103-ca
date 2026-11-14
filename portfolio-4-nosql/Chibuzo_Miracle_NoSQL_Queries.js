/**
 * CareLink Clinic — MongoDB sample inserts, indexes, and queries
 * Document type: NoSQL_Queries
 * Student: Chibuzo Miracle (301888687)
 * File: Chibuzo_Miracle_NoSQL_Queries.js
 *
 * Target: MongoDB 6+ (mongosh)
 * Usage:
 *   mongosh
 *   load("Chibuzo_Miracle_NoSQL_Queries.js")
 *
 * Aligns with Portfolio 1 entities/codes and Chibuzo_Miracle_MongoDocuments.json.
 */

const dbName = "carelink_clinical";
db = db.getSiblingDB(dbName);

// ---------------------------------------------------------------------------
// Optional clean rebuild for demo
// ---------------------------------------------------------------------------
db.patients.drop();
db.encounters.drop();

// ---------------------------------------------------------------------------
// Collection validation (JSON Schema) — implementation evidence
// ---------------------------------------------------------------------------
db.createCollection("patients", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["patientNumber", "firstName", "lastName", "dateOfBirth", "gender", "phone"],
      properties: {
        patientNumber: { bsonType: "string", pattern: "^PAT-" },
        firstName: { bsonType: "string" },
        lastName: { bsonType: "string" },
        dateOfBirth: { bsonType: ["date", "string"] },
        gender: {
          enum: ["female", "male", "other", "prefer_not_to_say"]
        },
        phone: { bsonType: "string" },
        preferredBranchCode: { bsonType: ["string", "null"] }
      }
    }
  }
});

db.createCollection("encounters", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: [
        "encounterKey",
        "appointmentId",
        "patientNumber",
        "doctor",
        "branch",
        "encounterAt"
      ],
      properties: {
        encounterKey: { bsonType: "string" },
        appointmentId: { bsonType: ["int", "long", "double"] },
        patientNumber: { bsonType: "string" },
        diagnoses: { bsonType: "array" },
        prescriptions: { bsonType: "array" },
        labOrders: { bsonType: "array" }
      }
    }
  }
});

// ---------------------------------------------------------------------------
// Indexes
// ---------------------------------------------------------------------------
db.patients.createIndex({ patientNumber: 1 }, { unique: true });
db.patients.createIndex({ "address.city": 1 });

db.encounters.createIndex({ encounterKey: 1 }, { unique: true });
db.encounters.createIndex({ appointmentId: 1 }, { unique: true });
db.encounters.createIndex({ patientNumber: 1, encounterAt: -1 });
db.encounters.createIndex({ "doctor.staffNumber": 1, encounterAt: -1 });
db.encounters.createIndex({ "branch.branchCode": 1, encounterAt: -1 });
db.encounters.createIndex({ "diagnoses.icdCode": 1 });
db.encounters.createIndex(
  { "clinicalNotes.subjective": "text", "clinicalNotes.assessment": "text", chiefComplaint: "text" },
  { name: "enc_clinical_text" }
);

// ---------------------------------------------------------------------------
// Inserts — patients (mirror P1 seed demographics)
// ---------------------------------------------------------------------------
db.patients.insertMany([
  {
    patientNumber: "PAT-1001",
    firstName: "Ibrahim",
    lastName: "Sule",
    dateOfBirth: ISODate("1990-04-12"),
    gender: "male",
    phone: "+2348030000001",
    email: "ibrahim.sule@example.com",
    address: { line1: "8 Opebi Road", city: "Ikeja" },
    emergency: { name: "Amina Sule", phone: "+2348030000099" },
    preferredBranchCode: "CL-IKE",
    createdAt: ISODate("2026-01-10T09:00:00Z"),
    updatedAt: ISODate("2026-03-15T11:20:00Z")
  },
  {
    patientNumber: "PAT-1002",
    firstName: "Blessing",
    lastName: "Ojo",
    dateOfBirth: ISODate("1985-11-03"),
    gender: "female",
    phone: "+2348030000002",
    email: "blessing.ojo@example.com",
    address: { line1: "22 Herbert Macaulay Way", city: "Yaba" },
    emergency: { name: "Kunle Ojo", phone: "+2348030000088" },
    preferredBranchCode: "CL-VI",
    createdAt: ISODate("2026-01-12T10:15:00Z"),
    updatedAt: ISODate("2026-02-28T16:00:00Z")
  }
]);

// ---------------------------------------------------------------------------
// Inserts — encounter aggregates (embedded diagnoses / Rx / labs)
// ---------------------------------------------------------------------------
db.encounters.insertMany([
  {
    encounterKey: "ENC-20260315-1001",
    appointmentId: 101,
    patientNumber: "PAT-1001",
    doctor: { staffNumber: "DOC-001", name: "Ada Okeke", specialtyCode: "GP" },
    branch: { branchCode: "CL-IKE", name: "CareLink Ikeja" },
    encounterAt: ISODate("2026-03-15T10:30:00Z"),
    chiefComplaint: "Fever, headache, and body aches for 3 days",
    clinicalNotes: {
      subjective:
        "Patient reports intermittent high-grade fever, frontal headache, and myalgia.",
      objective: "Alert, febrile. Mild conjunctival pallor. Chest clear.",
      assessment: "Suspected malaria; rule out bacterial infection.",
      plan: "Order MP and FBC. Start antipyretic.",
      vitals: {
        bpSystolic: 118,
        bpDiastolic: 76,
        pulse: 98,
        tempC: 38.6,
        weightKg: 72.4,
        spo2: 98
      },
      extraObservations: { travelHistory: "None in past month", allergyNotes: "NKDA" }
    },
    diagnoses: [
      {
        icdCode: "B54",
        description: "Unspecified malaria",
        severity: "moderate",
        diagnosedAt: ISODate("2026-03-15T10:45:00Z")
      },
      {
        icdCode: "R50.9",
        description: "Fever, unspecified",
        severity: "mild",
        diagnosedAt: ISODate("2026-03-15T10:45:00Z")
      }
    ],
    prescriptions: [
      {
        medicationCode: "MED-PARA",
        medicationName: "Paracetamol",
        dosage: "1 g",
        frequency: "every 6 hours as needed",
        durationDays: 3,
        instructions: "Take after food. Do not exceed 4 g in 24 hours.",
        status: "dispensed"
      },
      {
        medicationCode: "MED-AMOX",
        medicationName: "Amoxicillin",
        dosage: "500 mg",
        frequency: "three times daily",
        durationDays: 5,
        instructions: "Complete the course even if symptoms improve.",
        status: "active"
      }
    ],
    labOrders: [
      {
        testCode: "LAB-MP",
        testName: "Malaria Parasite",
        status: "completed",
        orderedAt: ISODate("2026-03-15T10:40:00Z"),
        resultedAt: ISODate("2026-03-15T13:10:00Z"),
        resultText: "Plasmodium falciparum trophozoites seen (+)",
        resultFlag: "abnormal",
        resultValues: { parasite: "P. falciparum", density: "+" }
      },
      {
        testCode: "LAB-FBC",
        testName: "Full Blood Count",
        status: "completed",
        orderedAt: ISODate("2026-03-15T10:40:00Z"),
        resultedAt: ISODate("2026-03-15T14:00:00Z"),
        resultText: "Mild anaemia; WBC within reference range",
        resultFlag: "abnormal",
        resultValues: { hb_g_dl: 11.2, wbc_x10e9_l: 6.8, plt_x10e9_l: 178 }
      }
    ],
    createdAt: ISODate("2026-03-15T10:50:00Z")
  },
  {
    encounterKey: "ENC-20260228-1002",
    appointmentId: 205,
    patientNumber: "PAT-1002",
    doctor: { staffNumber: "DOC-003", name: "Ngozi Eze", specialtyCode: "CARD" },
    branch: { branchCode: "CL-VI", name: "CareLink Victoria Island" },
    encounterAt: ISODate("2026-02-28T15:00:00Z"),
    chiefComplaint: "Palpitations and occasional chest discomfort on exertion",
    clinicalNotes: {
      subjective: "Episodes of rapid heartbeat lasting 5–10 minutes after exertion.",
      objective: "Regular rhythm at rest. No murmurs.",
      assessment: "Possible arrhythmia; investigate and follow up.",
      plan: "Baseline FBC. Cardiology follow-up in 4 weeks.",
      vitals: {
        bpSystolic: 142,
        bpDiastolic: 88,
        pulse: 92,
        tempC: 36.7,
        weightKg: 68.0,
        spo2: 99
      },
      extraObservations: {
        ecgSummary: "Sinus tachycardia; no acute ischaemic changes reported",
        nyhaClass: "I"
      }
    },
    diagnoses: [
      {
        icdCode: "R00.2",
        description: "Palpitations",
        severity: "moderate",
        diagnosedAt: ISODate("2026-02-28T15:25:00Z")
      },
      {
        icdCode: "I10",
        description: "Essential (primary) hypertension",
        severity: "mild",
        diagnosedAt: ISODate("2026-02-28T15:25:00Z")
      }
    ],
    prescriptions: [
      {
        medicationCode: "MED-PARA",
        medicationName: "Paracetamol",
        dosage: "500 mg",
        frequency: "as needed for headache",
        durationDays: 7,
        instructions: "Only if required; review BP at follow-up.",
        status: "active"
      }
    ],
    labOrders: [
      {
        testCode: "LAB-FBC",
        testName: "Full Blood Count",
        status: "completed",
        orderedAt: ISODate("2026-02-28T15:20:00Z"),
        resultedAt: ISODate("2026-02-28T17:45:00Z"),
        resultText: "Within reference ranges",
        resultFlag: "normal",
        resultValues: { hb_g_dl: 13.1, wbc_x10e9_l: 5.9, plt_x10e9_l: 240 }
      }
    ],
    createdAt: ISODate("2026-02-28T15:30:00Z")
  },
  {
    encounterKey: "ENC-20260402-1001",
    appointmentId: 118,
    patientNumber: "PAT-1001",
    doctor: { staffNumber: "DOC-001", name: "Ada Okeke", specialtyCode: "GP" },
    branch: { branchCode: "CL-IKE", name: "CareLink Ikeja" },
    encounterAt: ISODate("2026-04-02T09:15:00Z"),
    chiefComplaint: "Follow-up after malaria treatment; residual fatigue",
    clinicalNotes: {
      subjective: "Fever resolved. Mild fatigue persists.",
      objective: "Afebrile. Good hydration.",
      assessment: "Recovering post-malaria.",
      plan: "Supportive care. Return if fever recurs.",
      vitals: {
        bpSystolic: 120,
        bpDiastolic: 78,
        pulse: 76,
        tempC: 36.8,
        weightKg: 71.9,
        spo2: 99
      },
      extraObservations: {
        allergyNotes: "NKDA",
        returnPrecautions: "Fever > 38C, dark urine, confusion"
      }
    },
    diagnoses: [
      {
        icdCode: "Z09",
        description: "Follow-up examination after treatment for other conditions",
        severity: "mild",
        diagnosedAt: ISODate("2026-04-02T09:30:00Z")
      }
    ],
    prescriptions: [],
    labOrders: [],
    createdAt: ISODate("2026-04-02T09:35:00Z")
  }
]);

print("Inserted patients:", db.patients.countDocuments());
print("Inserted encounters:", db.encounters.countDocuments());

// ---------------------------------------------------------------------------
// Q1 — Longitudinal patient timeline (cross-branch history, one read path)
// Maps to CareLink operation: retrieve patient history
// ---------------------------------------------------------------------------
const timeline = db.encounters
  .find(
    { patientNumber: "PAT-1001" },
    {
      encounterKey: 1,
      encounterAt: 1,
      "branch.branchCode": 1,
      "doctor.name": 1,
      chiefComplaint: 1,
      "diagnoses.icdCode": 1,
      "diagnoses.description": 1
    }
  )
  .sort({ encounterAt: -1 })
  .toArray();

print("\n=== Q1 Patient timeline PAT-1001 ===");
printjson(timeline);

// ---------------------------------------------------------------------------
// Q2 — Single visit chart with embedded clinical children (no multi-table join)
// ---------------------------------------------------------------------------
const visitChart = db.encounters.findOne({ encounterKey: "ENC-20260315-1001" });
print("\n=== Q2 Full visit aggregate ENC-20260315-1001 ===");
printjson(visitChart);

// ---------------------------------------------------------------------------
// Q3 — Abnormal / critical lab flags for follow-up worklists
// ---------------------------------------------------------------------------
const abnormalLabs = db.encounters
  .aggregate([
    { $unwind: "$labOrders" },
    { $match: { "labOrders.resultFlag": { $in: ["abnormal", "critical"] } } },
    {
      $project: {
        patientNumber: 1,
        encounterAt: 1,
        testCode: "$labOrders.testCode",
        resultFlag: "$labOrders.resultFlag",
        resultText: "$labOrders.resultText",
        "doctor.name": 1,
        "branch.branchCode": 1
      }
    },
    { $sort: { encounterAt: -1 } }
  ])
  .toArray();

print("\n=== Q3 Abnormal lab worklist ===");
printjson(abnormalLabs);

// ---------------------------------------------------------------------------
// Q4 — Active prescriptions for pharmacy (status filter inside embed)
// ---------------------------------------------------------------------------
const activeRx = db.encounters
  .aggregate([
    { $unwind: "$prescriptions" },
    { $match: { "prescriptions.status": "active" } },
    {
      $project: {
        patientNumber: 1,
        medicationCode: "$prescriptions.medicationCode",
        medicationName: "$prescriptions.medicationName",
        dosage: "$prescriptions.dosage",
        frequency: "$prescriptions.frequency",
        durationDays: "$prescriptions.durationDays",
        doctorName: "$doctor.name",
        branchCode: "$branch.branchCode"
      }
    }
  ])
  .toArray();

print("\n=== Q4 Active prescriptions ===");
printjson(activeRx);

// ---------------------------------------------------------------------------
// Q5 — Text search over clinical notes (flexible narrative content)
// ---------------------------------------------------------------------------
const noteHits = db.encounters
  .find(
    { $text: { $search: "malaria fever" } },
    { score: { $meta: "textScore" }, encounterKey: 1, patientNumber: 1, chiefComplaint: 1 }
  )
  .sort({ score: { $meta: "textScore" } })
  .toArray();

print("\n=== Q5 Clinical text search ===");
printjson(noteHits);

// ---------------------------------------------------------------------------
// Q6 — Update: append a structured lab result field without schema migration
// Demonstrates document flexibility vs relational ALTER TABLE
// ---------------------------------------------------------------------------
db.encounters.updateOne(
  { encounterKey: "ENC-20260315-1001", "labOrders.testCode": "LAB-MP" },
  {
    $set: {
      "labOrders.$.resultValues.speciesConfirmed": true,
      "labOrders.$.resultValues.reviewedBy": "LAB-TECH-01"
    }
  }
);

print("\n=== Q6 After flexible lab field update ===");
printjson(
  db.encounters.findOne(
    { encounterKey: "ENC-20260315-1001" },
    { "labOrders.$": 1 }
  )
);

// ---------------------------------------------------------------------------
// Q7 — Aggregation: diagnosis counts by specialty (manager insight)
// Still often better in SQL for finance; shown for clinical analytics
// ---------------------------------------------------------------------------
const dxBySpecialty = db.encounters
  .aggregate([
    { $unwind: "$diagnoses" },
    {
      $group: {
        _id: {
          specialty: "$doctor.specialtyCode",
          icd: "$diagnoses.icdCode"
        },
        count: { $sum: 1 },
        sampleDescription: { $first: "$diagnoses.description" }
      }
    },
    { $sort: { count: -1 } }
  ])
  .toArray();

print("\n=== Q7 Diagnosis counts by specialty ===");
printjson(dxBySpecialty);

print("\nPortfolio 4 MongoDB demo script finished.");
