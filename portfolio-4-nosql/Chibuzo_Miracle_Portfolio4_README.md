# Portfolio 4: NoSQL and Advanced Data Models

**Course:** MIT 8103 Advanced Database Systems  
**Student:** Chibuzo Miracle  
**Student ID:** 301888687  
**Marks:** 7  
**Case study:** CareLink Clinic (multi-branch outpatient clinic)  
**Depends on:** Portfolio 1 relational schema (`Branch`, `Specialty`, `Staff`, `Patient`, `Appointment`, `Encounter`, `Diagnosis`, `Medication`, `Prescription`, `LabTest`, `LabOrder`, `Service`, `Payment`)

## Deliverables

| File | Document type | Status |
|------|---------------|--------|
| [Chibuzo_Miracle_NoSQL_Model.md](Chibuzo_Miracle_NoSQL_Model.md) | NoSQL model + suitability vs relational | Complete |
| [Chibuzo_Miracle_MongoDocuments.json](Chibuzo_Miracle_MongoDocuments.json) | Sample patient / encounter documents | Complete |
| [Chibuzo_Miracle_NoSQL_Queries.js](Chibuzo_Miracle_NoSQL_Queries.js) | MongoDB validators, inserts, indexes, queries | Complete |
| [Chibuzo_Miracle_Redis_KeyValue.md](Chibuzo_Miracle_Redis_KeyValue.md) | Redis key–value slots / sessions | Complete |
| Chibuzo_Miracle_Portfolio4_README.md (this file) | Portfolio guide | Complete |

## What This Portfolio Covers

1. **Document store (MongoDB)** — longitudinal patient chart; encounter aggregate with nested diagnoses, prescriptions, and lab orders; flexible clinical notes / vitals  
2. **Key–value (Redis)** — appointment slot cache, booking holds, staff sessions, check-in flags  
3. **Graph (Neo4j, conceptual)** — referral / specialty coverage network across staff and branches  
4. Clear **hybrid** argument: what stays in PostgreSQL vs what moves to NoSQL  

## Paradigm → CareLink operation map

| CareLink operation | Best store | Why |
|--------------------|------------|-----|
| Register / update demographics | PostgreSQL (+ optional Mongo `patients`) | Strong identity; document copy aids chart reads |
| Book / cancel appointment | PostgreSQL + Redis slots | Unique slot integrity + fast calendar |
| Record encounter + diagnoses + Rx + labs | MongoDB `encounters` (+ SQL if dual-write) | One aggregate read; flexible notes |
| Pharmacy active prescriptions | Mongo unwind / SQL | Document embed convenient for visit context |
| Lab abnormal worklist | Mongo aggregation | Nested `labOrders.resultFlag` |
| Payments / pricing | PostgreSQL only | Numeric / FK integrity |
| Referral path discovery | Neo4j (optional) | Multi-hop staff–specialty graph |

## How to Run the MongoDB Evidence

```bash
mongosh
load("Chibuzo_Miracle_NoSQL_Queries.js")
```

Or paste sections of the script into MongoDB Compass / `mongosh` connected to a local server. Sample static JSON for reading without a server: `Chibuzo_Miracle_MongoDocuments.json`.

## How to Review Redis Evidence

Open `Chibuzo_Miracle_Redis_KeyValue.md` and run the `redis-cli` examples against a local Redis instance (optional for marking; commands are self-contained).

## Suggested Review Order

1. This README — scope and file map  
2. `Chibuzo_Miracle_NoSQL_Model.md` — architecture and suitability analysis  
3. `Chibuzo_Miracle_MongoDocuments.json` — concrete document shapes  
4. `Chibuzo_Miracle_NoSQL_Queries.js` — insert / query / update evidence  
5. `Chibuzo_Miracle_Redis_KeyValue.md` — key–value operational patterns  

## Academic Integrity

Implementation and analysis are individual work for MIT 8103 continuous assessment. The CareLink case study and entity names are consistent with Portfolio 1.
