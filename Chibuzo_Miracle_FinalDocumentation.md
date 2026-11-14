# MIT 8103 — Final Portfolio Documentation

**Student:** Chibuzo Miracle · **ID:** 301888687  
**Course:** MIT 8103 Advanced Database Systems · **Assessment:** Continuous Assessment (40 marks)  
**Case study:** CareLink Clinic (multi-branch outpatient)  
**GitHub repository:** https://github.com/mchibuzo8687/mit-8103-ca  

*This file is the LMS upload (≈2–3 pages). The root README is a repo guide only — do not submit it as the sole summary.*

---

## 1. Selected organisation / case study

**CareLink Clinic** is a simulated private multi-branch outpatient network (not a tertiary inpatient hospital). Care is appointment-driven, with limited same-day walk-ins. The database supports day-to-day clinic operations while keeping a consistent patient record across branches (e.g. Ikeja, Victoria Island).

| Aspect | Detail |
|--------|--------|
| **Users** | Reception, doctors, nurses, laboratory staff, pharmacists, branch managers; limited patient self-service views |
| **Major data** | Branches, staff, specialties, patients, appointments, encounters, diagnoses, prescriptions/medications, lab tests/orders/results, services, payments |
| **Key operations** | Register/update patient; book/cancel/complete appointment; record encounter & diagnosis; prescribe & dispense; order labs & store results; take payment; retrieve cross-branch clinical history |

Full narrative: `portfolio-1-database-design/Chibuzo_Miracle_CaseStudy.md`.

---

## 2. Portfolio activities (1–5)

### Portfolio 1 — Database design and modelling
Defined the CareLink case study, Mermaid ER model with cardinalities, PostgreSQL DDL (`Chibuzo_Miracle_Schema.sql`), keys/constraints inventory, and normalisation to 3NF (BCNF notes). **Evidence:** `portfolio-1-database-design/` — CaseStudy, ERDiagram, Schema.sql, KeysConstraints, Normalisation; ER export under `screenshots/`.

### Portfolio 2 — Query processing and optimisation
Seeded operational data; wrote ten clinic queries (schedules, history, revenue, labs, pharmacy, no-shows); added indexes; documented EXPLAIN-style before/after reasoning. **Evidence:** `portfolio-2-query-optimisation/` — SeedData.sql, Queries.sql, Indexes.sql, QueryOptimisation.md.

### Portfolio 3 — Transactions and concurrency
Implemented multi-statement clinic transactions (commit visit path; rollback on failed payment); analysed isolation levels and anomalies (double-booking via `uq_doctor_slot`, lost update, dirty/phantom reads) with locking/isolation controls. **Evidence:** `portfolio-3-transactions-concurrency/` — Transactions.sql, Concurrency.md.

### Portfolio 4 — NoSQL and advanced models
Hybrid design: MongoDB for longitudinal charts / nested encounter aggregates; Redis for slot cache, holds, sessions; Neo4j conceptually for referral networks; clear split of what stays in PostgreSQL. **Evidence:** `portfolio-4-nosql/` — NoSQL_Model.md, MongoDocuments.json, NoSQL_Queries.js, Redis_KeyValue.md.

### Portfolio 5 — Distributed and cloud
Documented multi-AZ managed PostgreSQL topology, sync standby + async read replicas, branch-oriented partitioning, CAP/PACELC trade-offs, and cloud/local deployment evidence (compose + Terraform-style snippets). **Evidence:** `portfolio-5-distributed-cloud/` — DistributedArchitecture.md, ReplicationSharding.md, CloudDeployment.md, CareLink_Compose.yml.

---

## 3. GitHub repository

**Required link:** https://github.com/mchibuzo8687/mit-8103-ca  

Clone or browse this URL for the full portfolio tree (`portfolio-1` … `portfolio-5`), SQL/JS artefacts, and documentation. Ensure the repository remains accessible to the lecturer (public or collaborator invite as required).

---

## 4. Supporting evidence

| Location | What assessors find |
|----------|---------------------|
| `screenshots/` | ER / tool captures (e.g. `pgerd.pgerd.png`, dated `Screenshot 2026-11-14 *.png`) — see `Chibuzo_Miracle_EvidenceNotes.md` for a short map |
| Portfolio folders | Source SQL, Mongo/Redis scripts, architecture write-ups listed in §2 |
| Portfolio READMEs | Run order (`psql` / `mongosh` / compose) and evidence labelling where live dual-session demos were documented realistically |

No fabricated image files were added. Where a live DBMS session was unavailable during authoring, plans/session logs in Portfolio 2–3 docs are labelled as **documented (realistic) evidence** aligned to the schema and indexes.

---

## 5. Individual technical reflection

**Design choices.** PostgreSQL was kept as the system of record for appointments, payments, and referential integrity; MongoDB was reserved for flexible clinical aggregates; Redis for short-lived operational state. Unique doctor–slot constraints and transactional payment flows were prioritised because double-booking and partial billing are high-risk clinic failures. For distribution, strong consistency on booking/payment and eventual consistency on cross-branch history reads matched CareLink’s multi-branch reality.

**Challenges.** Balancing 3NF purity with query-friendly joins; writing optimisation commentary that stays honest when a live `EXPLAIN ANALYZE` environment was intermittent; reasoning about isolation without always running two concurrent sessions; keeping NoSQL documents aligned with relational keys without inventing a full dual-write product.

**Lessons.** Indexes must follow measured access paths (date, patient, doctor, branch), not guesswork; transactions are business workflows, not only `BEGIN`/`COMMIT` syntax; hybrid stores need an explicit ownership boundary; cloud topology is only useful when tied to concrete CareLink operations and failure modes.

---

## 6. References

1. Elmasri, R. & Navathe, S. B. — *Fundamentals of Database Systems* (normalisation, ER, transactions).  
2. PostgreSQL Documentation — DDL, indexes, `EXPLAIN`, isolation levels, partitioning.  
3. MongoDB Manual — document modelling, aggregation; Redis documentation — key–value patterns.  
4. Brewer / Gilbert–Lynch (CAP); PACELC discussion for distributed trade-offs.  
5. Course materials: MIT 8103 Advanced Database Systems, Continuous Assessment brief (2026/2027).

### AI use declaration

**Tool:** Cursor (Composer / agent-assisted editing) was used for structuring folders, drafting Markdown/SQL skeletons, Mermaid diagrams, and consistency of CareLink naming across portfolios.  

**Student verification:** All schema objects, queries, transaction scenarios, NoSQL models, and distributed designs were reviewed and edited by the student against the CareLink case study and course requirements. SQL/JS were checked for alignment with Portfolio 1 entities; optimisation and concurrency write-ups were validated conceptually against PostgreSQL behaviour; final wording in this LMS document was confirmed by the student. AI did not replace individual analysis or academic judgment. No production credentials or patient data were used.
