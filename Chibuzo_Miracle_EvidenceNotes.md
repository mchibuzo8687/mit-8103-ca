# Evidence notes — where assessors find outputs

**Student:** Chibuzo Miracle (301888687)  
**Companion to:** `Chibuzo_Miracle_FinalDocumentation.md`  
**GitHub:** https://github.com/mchibuzo8687/mit-8103-ca

This file maps existing artefacts only. It does not invent screenshot files.

## Screenshots folder (`screenshots/`)

| File | Typical use for marking |
|------|-------------------------|
| `Chibuzo_Miracle_ERDiagram.pgerd` / `Chibuzo_Miracle_ERDiagram_Export.png` | ER / schema visual from design tooling (Portfolio 1) |
| `Chibuzo_Miracle_Screenshot_2026-11-14_193135.png` | Tool / workspace capture |
| `Chibuzo_Miracle_Screenshot_2026-11-14_195301.png` | Tool / workspace capture |
| `Chibuzo_Miracle_Screenshot_2026-11-14_195326.png` | Tool / workspace capture |
| `Chibuzo_Miracle_Screenshot_2026-11-14_195658.png` | Tool / workspace capture |
| `Chibuzo_Miracle_Screenshot_2026-11-14_195942.png` | Tool / workspace capture |

Exact screen content should be judged by opening the PNGs; timestamps in filenames are from the authoring session.

## Textual / executable evidence by portfolio

| Portfolio | Primary evidence paths |
|-----------|------------------------|
| 1 Design | `portfolio-1-database-design/Chibuzo_Miracle_Schema.sql`, `…_ERDiagram.md`, `…_Normalisation.md`, `…_KeysConstraints.md` |
| 2 Queries | `…_Queries.sql`, `…_Indexes.sql`, `…_QueryOptimisation.md` (EXPLAIN commentary) |
| 3 Txn/concurrency | `…_Transactions.sql`, `…_Concurrency.md` |
| 4 NoSQL | `…_MongoDocuments.json`, `…_NoSQL_Queries.js`, `…_Redis_KeyValue.md`, `…_NoSQL_Model.md` |
| 5 Distributed/cloud | `…_DistributedArchitecture.md`, `…_ReplicationSharding.md`, `…_CloudDeployment.md`, `…_CareLink_Compose.yml` |

## Documented vs live runtime

Portfolios 2–3 note where outputs are **documented (realistic)** when a live dual-session or EXPLAIN run was not available during authoring. Assessors should treat those write-ups as reasoned evidence tied to the submitted schema and scripts, alongside any screenshots present in `screenshots/`.
