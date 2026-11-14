# Portfolio 5 — Distributed and Cloud Database Exercise

**Student:** Chibuzo Miracle  
**Student ID:** 301888687  
**Course:** MIT 8103 — Advanced Database Systems  
**Case study:** CareLink Clinic  
**DBMS focus:** Managed PostgreSQL (primary OLTP) with optional MongoDB Atlas link to Portfolio 4  
**Status:** Complete

## Purpose

Design and document a realistic **distributed / cloud** database deployment for CareLink Clinic — the same multi-branch outpatient case study used in Portfolios 1–3 — covering replication, branch-oriented partitioning/sharding, availability vs consistency trade-offs (CAP / PACELC), and cloud deployment evidence.

## Schema dependency

Aligns with entities in `../portfolio-1-database-design/Chibuzo_Miracle_Schema.sql`:

Branch, Specialty, Staff, Patient, Appointment, Encounter, Diagnosis, Medication, Prescription, LabTest, LabOrder, Service, Payment.

Portfolio 1–3 files are **not** modified. This portfolio reasons about how that relational model would be **placed, replicated, and partitioned** across cloud regions / Availability Zones for multi-branch operations.

## Deliverables

| File | Description |
|------|-------------|
| `Chibuzo_Miracle_Portfolio5_README.md` | This overview |
| `Chibuzo_Miracle_DistributedArchitecture.md` | Target topology, data placement, Mermaid architecture diagram, CareLink operation mapping |
| `Chibuzo_Miracle_ReplicationSharding.md` | Replication modes, branch sharding/partitioning, CAP / PACELC trade-offs |
| `Chibuzo_Miracle_CloudDeployment.md` | Managed PostgreSQL evidence: docker-compose (local), Terraform-style snippets, failover notes |

## Design summary (CareLink)

| Concern | CareLink choice |
|---------|-----------------|
| Primary store | Managed PostgreSQL (multi-AZ) for transactional clinic data |
| Replication | Sync standby (same region, second AZ) for failover; async read replicas for history / analytics |
| Partitioning | Declarative partitioning of high-volume tables by `branch_id` (Ikeja / Victoria Island and future branches) |
| Consistency | Strong consistency for booking & payments; eventual consistency acceptable for cross-branch history reads |
| Optional NoSQL | MongoDB Atlas (Portfolio 4) for flexible clinical-note documents, eventually consistent with relational encounters |

## How the pieces fit together

1. Read **DistributedArchitecture** for the end-to-end picture and operation mapping.  
2. Read **ReplicationSharding** for mechanisms and CAP / PACELC reasoning.  
3. Read **CloudDeployment** for concrete config evidence (compose + Terraform-style).

## Academic integrity

Design decisions and documentation are individual work for MIT 8103 Continuous Assessment. Cloud vendor product names are used as realistic deployment examples; no production credentials are included.
